import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/scheduler.dart';

import 'package:interval_ear/core/audio/audio_playback_event.dart';
import 'package:interval_ear/core/audio/audio_player_backend.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/core/audio/cache/audio_buffer_cache.dart';
import 'package:interval_ear/core/audio/sfx_catalog.dart';
import 'package:interval_ear/core/audio/soloud_backend.dart';
import 'package:interval_ear/core/audio/synth/sequence_builder.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 基于 SoLoud 的 [AudioService] 实现（架构 §1.3 / §3.4）。
///
/// 关键职责：
/// 1. **防重叠**：每次 `playSequence`/`playComparison` 先取消上一段（emit `cancelled`
///    + 停 Ticker + 停旧 voice），再放出新 playbackId。UI 按 `playbackId` 过滤，
///    旧 id 的事件被自然丢弃（T09 验收 2）。
/// 2. **位置轮询**：只在播放中用 `Ticker` 驱动 `getPosition`，逐帧推进时间轴事件；
///    播放结束**必须**停 Ticker（无泄漏，T09 验收 3）。
/// 3. **降级**：`initialize()` 失败 → [isAvailable]=false，所有播放方法优雅退化，
///    绝不抛异常（T09 验收 4）。真正的「换 Fake」由 AppBootstrap 完成，本类只保证不崩。
class SoLoudAudioService implements AudioService {
  /// 构造。[backend]/[cache] 可注入以便测试。
  factory SoLoudAudioService({
    AudioPlayerBackend? backend,
    AudioBufferCache? cache,
  }) {
    final AudioPlayerBackend resolvedBackend = backend ?? SoLoudBackend();
    return SoLoudAudioService._(
      resolvedBackend,
      cache ?? AudioBufferCache(backend: resolvedBackend),
    );
  }

  SoLoudAudioService._(this._backend, this._cache);

  final AudioPlayerBackend _backend;
  final AudioBufferCache _cache;

  final StreamController<AudioPlaybackEvent> _controller =
      StreamController<AudioPlaybackEvent>.broadcast();

  Ticker? _ticker;
  int _playbackId = 0;
  int _currentPlaybackId = 0;
  AudioTimeline? _timeline;
  int _nextMarkIndex = 0;
  PlayingVoice? _handle;
  bool _isAvailable = false;
  double _volume = 1.0;
  Timbre _timbre = Timbre.keyboard;

  // 位置轮询降级（§1.3.3：连续 5 帧未推进且 voice 仍存活 → 用 Stopwatch）。
  final Stopwatch _fallbackClock = Stopwatch();
  bool _useFallback = false;
  int _staleFrames = 0;
  Duration _lastPos = Duration.zero;

  // 音效队列（播放中入队，sequenceEnd + 80ms 后播；切题则丢弃）。
  final Queue<(SfxId, int)> _pendingSfx = Queue<(SfxId, int)>();

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isPlaying => _ticker?.isActive ?? false;

  @override
  int get currentPlaybackId => _currentPlaybackId;

  @override
  Stream<AudioPlaybackEvent> get events => _controller.stream;

  @override
  Future<void> initialize() async {
    try {
      await _backend.init(AppConfig.sampleRate, 2048);
      _isAvailable = true;
    } catch (e) {
      // 关键：初始化失败绝不向上抛，置为不可用即可。AppBootstrap 据此换 Fake。
      _isAvailable = false;
      _emit(AudioPlaybackEvent.error(
        _currentPlaybackId,
        'audio backend init failed: $e',
      ));
    }
  }

  @override
  Future<int> playSequence(AudioSequenceSpec spec) async {
    if (!_isAvailable) {
      // 降级：不可用时不发声，但返回合法 id 且不崩溃。
      final int id = ++_playbackId;
      _emit(AudioPlaybackEvent.error(id, 'audio backend unavailable'));
      return id;
    }
    _cancelCurrent();
    final int id = ++_playbackId;
    final SequenceRender render;
    try {
      render = _cache.getOrBuild(spec);
    } catch (e) {
      _emit(AudioPlaybackEvent.error(id, 'synth failed: $e'));
      return id;
    }
    await _playRender(render, id, spec.timbre, spec.gain, spec.cacheKey());
    return id;
  }

  @override
  Future<int> playComparison(
    List<AudioSequenceSpec> specs,
    Duration gapBetween,
  ) async {
    if (!_isAvailable) {
      final int id = ++_playbackId;
      _emit(AudioPlaybackEvent.error(id, 'audio backend unavailable'));
      return id;
    }
    _cancelCurrent();
    final int id = ++_playbackId;
    final SequenceRender render;
    try {
      render = SequenceBuilder.buildComparison(specs, gapBetween);
    } catch (e) {
      _emit(AudioPlaybackEvent.error(id, 'synth failed: $e'));
      return id;
    }
    // 对比播放用第一个 spec 的音色作占位（事件里的 timbre 仅用于可视化风格）。
    final Timbre timbre =
        specs.isNotEmpty ? specs.first.timbre : Timbre.keyboard;
    final String cacheKey = 'comparison-${gapBetween.inMicroseconds}-'
        '${specs.map((AudioSequenceSpec spec) => spec.cacheKey()).join('|')}';
    await _playRender(render, id, timbre, 1.0, cacheKey);
    return id;
  }

  /// 真正驱动一次播放：加载 → 播放 → 起 Ticker。
  Future<void> _playRender(
    SequenceRender render,
    int id,
    Timbre timbre,
    double gain,
    String cacheKey,
  ) async {
    _timbre = timbre;
    LoadedAudio loaded;
    try {
      loaded = await _cache.getLoaded(
        cacheKey,
        render.wav,
      );
    } catch (e) {
      _emit(AudioPlaybackEvent.error(id, 'load failed: $e'));
      return;
    }
    _timeline = render.timeline;
    _nextMarkIndex = 0;
    _currentPlaybackId = id;
    // 起播前先把 t=0 的标记（sequenceStart / noteStart@0）推一遍。
    _emit(AudioPlaybackEvent.sequenceStart(id, timbre: timbre));
    _emitDue(Duration.zero);
    try {
      _handle = _backend.playSource(loaded, (_volume * gain).clamp(0.0, 1.0));
    } catch (e) {
      _emit(AudioPlaybackEvent.error(id, 'play failed: $e'));
      return;
    }
    _startTicker();
  }

  @override
  Future<void> playSfx(SfxId id) async {
    if (!_isAvailable) {
      return;
    }
    if (isPlaying) {
      // 播放中入队，sequenceEnd + 80ms 后播；切题则丢弃（PRD §5.2 互斥）。
      _pendingSfx.add((id, _currentPlaybackId));
      return;
    }
    await _playSfxNow(id);
  }

  Future<void> _playSfxNow(SfxId id) async {
    try {
      final Uint8List wav = SfxCatalog.wavFor(id);
      final LoadedAudio loaded = await _backend.load('sfx-${id.name}', wav);
      _backend.playSource(loaded, _volume);
      // SFX 短且独立，不进时间线、不跟踪 handle（SoLoud 支持多 voice 并发）。
    } catch (_) {
      // 音效失败绝不能影响主流程。
    }
  }

  @override
  Future<void> stop() async {
    _cancelCurrent();
    _pendingSfx.clear();
  }

  @override
  Future<void> preload(Iterable<AudioSequenceSpec> specs) async {
    if (!_isAvailable) {
      return;
    }
    for (final AudioSequenceSpec spec in specs) {
      try {
        final SequenceRender render = _cache.getOrBuild(spec);
        await _cache.getLoaded(spec.cacheKey(), render.wav);
      } catch (_) {
        // 预加载失败不阻断主流程。
      }
    }
  }

  @override
  void setMasterVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _backend.setGlobalVolume(_volume);
  }

  @override
  Future<void> dispose() async {
    _cancelCurrent();
    _pendingSfx.clear();
    if (!_controller.isClosed) {
      await _controller.close();
    }
    try {
      await _cache.dispose();
      await _backend.shutdown();
    } catch (_) {
      // 忽略。
    }
  }

  // ---------------------------------------------------------------------------
  // 内部：取消 / Ticker / 事件推进
  // ---------------------------------------------------------------------------

  /// 取消当前播放：停 voice + 停 Ticker + emit cancelled（旧 id）。
  void _cancelCurrent() {
    if (_handle != null) {
      _backend.stopVoice(_handle!);
      _handle = null;
    }
    _stopTicker();
    if (_currentPlaybackId != 0) {
      _emit(AudioPlaybackEvent.cancelled(_currentPlaybackId));
    }
  }

  /// 每帧回调：取位置 → 推进 due 标记 → 判断是否结束。
  void _onTick(Duration _) {
    if (_timeline == null || _handle == null) {
      _stopTicker();
      return;
    }
    final Duration pos = _resolvePosition();
    _emitDue(pos);
    final bool alive = _backend.isAlive(_handle!);
    if (!alive || pos >= _timeline!.total) {
      // 确保 sequenceEnd 一定发出（补齐尚未推到的标记）。
      _emitRemaining();
      _handle = null;
      _stopTicker();
      _flushPendingSfx();
    }
  }

  /// 解析当前播放位置；连续 5 帧停滞则降级到 Stopwatch（§1.3.3）。
  Duration _resolvePosition() {
    if (_handle == null) {
      return Duration.zero;
    }
    if (_useFallback) {
      return _fallbackClock.elapsed;
    }
    final Duration pos = _backend.positionOf(_handle!);
    if (pos == _lastPos) {
      _staleFrames++;
      if (_staleFrames >= 5) {
        _useFallback = true;
        return _fallbackClock.elapsed;
      }
    } else {
      _staleFrames = 0;
      _lastPos = pos;
    }
    return pos;
  }

  /// 发出所有 `at <= pos` 的标记（带当前 playbackId）。
  void _emitDue(Duration pos) {
    if (_timeline == null) {
      return;
    }
    while (_nextMarkIndex < _timeline!.marks.length &&
        _timeline!.marks[_nextMarkIndex].at <= pos) {
      final AudioTimelineMark mark = _timeline!.marks[_nextMarkIndex];
      _emit(
        AudioPlaybackEvent(
          type: mark.type,
          playbackId: _currentPlaybackId,
          noteIndex: mark.noteIndex,
          segmentIndex: mark.segmentIndex,
          position: pos,
          noteDuration: mark.noteDuration,
          timbre: _timbre,
        ),
      );
      _nextMarkIndex++;
    }
  }

  /// 补齐尚未发出的剩余标记（停止时保证 sequenceEnd 必发）。
  void _emitRemaining() {
    if (_timeline == null) {
      return;
    }
    while (_nextMarkIndex < _timeline!.marks.length) {
      final AudioTimelineMark mark = _timeline!.marks[_nextMarkIndex];
      _emit(
        AudioPlaybackEvent(
          type: mark.type,
          playbackId: _currentPlaybackId,
          noteIndex: mark.noteIndex,
          segmentIndex: mark.segmentIndex,
          position: mark.at,
          noteDuration: mark.noteDuration,
          timbre: _timbre,
        ),
      );
      _nextMarkIndex++;
    }
  }

  /// sequenceEnd 后把排队的音效在 80ms 后播（若已切题则丢弃）。
  void _flushPendingSfx() {
    if (_pendingSfx.isEmpty) {
      return;
    }
    final (SfxId id, int enqueueId) = _pendingSfx.removeFirst();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      // 期间若启动了新序列（playbackId 改变）则丢弃该音效。
      if (_currentPlaybackId == enqueueId && !isPlaying) {
        _playSfxNow(id);
      }
    });
  }

  void _startTicker() {
    _stopTicker();
    _fallbackClock
      ..reset()
      ..start();
    _useFallback = false;
    _staleFrames = 0;
    _lastPos = Duration.zero;
    _ticker = Ticker(_onTick)..start();
  }

  void _stopTicker() {
    if (_ticker != null) {
      _ticker!.stop();
      _ticker = null;
    }
  }

  void _emit(AudioPlaybackEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
}
