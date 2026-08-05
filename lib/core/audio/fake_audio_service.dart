import 'dart:async';

import 'package:interval_ear/core/audio/audio_playback_event.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/core/audio/sfx_catalog.dart';
import 'package:interval_ear/core/audio/synth/sequence_builder.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 降级 / 测试用的 [AudioService] 实现（架构 §3.4 / T09 验收 5）。
///
/// **不依赖任何原生音频引擎**：用一条「虚拟时钟」按时间线发出完整事件序列，使阶段 3
/// 的所有 UI 测试都能在纯 Dart 下确定性运行。测试通过 [advance] 手动推进虚拟时钟，
/// 事件在 `advance` 内**同步**发出，无需等待真实计时器——彻底消除 flaky。
///
/// 关键设计：事件带正确的 `playbackId`；新播放取消旧播放（emit `cancelled`，旧 id
/// 事件停止发出），与真机 [SoLoudAudioService] 行为一致。
class FakeAudioService implements AudioService {
  /// 构造。[available] 默认可用；测试降级场景可传 `false`。
  FakeAudioService({this.available = true});

  /// 是否可用（对应真机 `initialize()` 成功）。
  final bool available;

  final StreamController<AudioPlaybackEvent> _controller =
      StreamController<AudioPlaybackEvent>.broadcast();

  int _playbackId = 0;
  int _currentPlaybackId = 0;
  AudioTimeline? _timeline;
  int _nextMarkIndex = 0;
  Duration _virtualPos = Duration.zero;
  bool _isPlaying = false;
  bool _initialized = false;
  Timbre _timbre = Timbre.keyboard;

  @override
  bool get isAvailable => _initialized && available;

  @override
  bool get isPlaying => _isPlaying;

  @override
  int get currentPlaybackId => _currentPlaybackId;

  @override
  Stream<AudioPlaybackEvent> get events => _controller.stream;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<int> playSequence(AudioSequenceSpec spec) async {
    if (!isAvailable) {
      final int id = ++_playbackId;
      _emit(AudioPlaybackEvent.error(id, 'fake audio unavailable'));
      return id;
    }
    _cancelCurrent();
    final int id = ++_playbackId;
    final SequenceRender render = SequenceBuilder.build(spec);
    _beginRender(render, id, spec.timbre);
    return id;
  }

  @override
  Future<int> playComparison(
    List<AudioSequenceSpec> specs,
    Duration gapBetween,
  ) async {
    if (!isAvailable) {
      final int id = ++_playbackId;
      _emit(AudioPlaybackEvent.error(id, 'fake audio unavailable'));
      return id;
    }
    _cancelCurrent();
    final int id = ++_playbackId;
    final SequenceRender render = SequenceBuilder.buildComparison(specs, gapBetween);
    final Timbre timbre =
        specs.isNotEmpty ? specs.first.timbre : Timbre.keyboard;
    _beginRender(render, id, timbre);
    return id;
  }

  /// 启动一次渲染：设置时间线，发出 t=0 的标记。
  void _beginRender(SequenceRender render, int id, Timbre timbre) {
    _timeline = render.timeline;
    _nextMarkIndex = 0;
    _virtualPos = Duration.zero;
    _currentPlaybackId = id;
    _isPlaying = true;
    _timbre = timbre;
    // sequenceStart + 同一时刻的 noteStart 等（mark 列表里已含 sequenceStart@0）。
    _emitDue(Duration.zero, timbre);
  }

  @override
  Future<void> playSfx(SfxId id) async {
    // 降级实现：音效在 Fake 下不发声、不阻塞（仅满足接口）。
  }

  @override
  Future<void> stop() async {
    _cancelCurrent();
  }

  @override
  Future<void> preload(Iterable<AudioSequenceSpec> specs) async {
    // Fake 无需预加载。
  }

  @override
  void setMasterVolume(double volume) {
    // Fake 不发声，音量仅作接口占位。
  }

  @override
  Future<void> dispose() async {
    _isPlaying = false;
    _timeline = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  // ---------------------------------------------------------------------------
  // 虚拟时钟（供测试驱动）
  // ---------------------------------------------------------------------------

  /// 推进虚拟时钟 [delta]，同步发出该区间内到期的事件。
  ///
  /// 这是 Fake 与真机的唯一差异：真机由 Ticker + 引擎位置驱动；Fake 由测试手动驱动，
  /// 从而完全确定、无 flaky（T09 验收 5）。
  void advance(Duration delta) {
    if (_timeline == null || !_isPlaying) {
      return;
    }
    _virtualPos += delta;
    _emitDue(_virtualPos, _timbre);
    if (_virtualPos >= _timeline!.total) {
      _emitRemaining();
      _isPlaying = false;
      _timeline = null;
      _nextMarkIndex = 0;
      _virtualPos = Duration.zero;
    }
  }

  /// 取消当前播放（防重叠）。
  void _cancelCurrent() {
    if (_isPlaying && _currentPlaybackId != 0) {
      _emit(AudioPlaybackEvent.cancelled(_currentPlaybackId));
    }
    _isPlaying = false;
    _timeline = null;
    _nextMarkIndex = 0;
    _virtualPos = Duration.zero;
  }

  void _emitDue(Duration pos, Timbre timbre) {
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
          timbre: timbre,
        ),
      );
      _nextMarkIndex++;
    }
  }

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

  void _emit(AudioPlaybackEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
}
