import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/audio_playback_event.dart';
import 'package:interval_ear/core/audio/audio_player_backend.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/core/audio/cache/audio_buffer_cache.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';
import 'package:interval_ear/core/audio/soloud_audio_service.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// T09 验收 1/2/3/4/5 + 任务清单：
/// - FakeAudioService 按虚拟时钟发出完整确定性事件序列（advance 手动推进）；
/// - 防重叠：新 playSequence 停旧、旧 playbackId 事件被丢弃；
/// - Ticker 播放结束必须停（无泄漏，用注入假 backend 测 SoLoudAudioService）；
/// - AudioPlaybackEvent 不含音高/频率/MIDI 字段（结构护栏）。

AudioSequenceSpec _spec({
  int root = 60,
  int target = 64,
  Timbre timbre = Timbre.keyboard,
  Duration? noteDuration,
  Duration? noteGap,
}) =>
    AudioSequenceSpec(
      rootMidiNote: root,
      targetMidiNote: target,
      direction: PlaybackDirection.ascending,
      timbre: timbre,
      noteDuration: noteDuration ?? AudioSequenceSpec.defaultNoteDuration,
      noteGap: noteGap ?? AudioSequenceSpec.defaultNoteGap,
    );

/// 可注入的假后端：用计数器模拟播放位置，便于确定性驱动 Ticker（无需真机原生音频）。
class _FakeBackend implements AudioPlayerBackend {
  _FakeBackend({this.keepAlive = false});

  final bool keepAlive;
  Duration _pos = Duration.zero;
  Duration _length = Duration.zero;
  int _srcCounter = 0;
  int _handleCounter = 0;
  final List<String> loadedKeys = <String>[];
  final List<Object> unloadedTokens = <Object>[];

  @override
  Future<void> init(int sampleRate, int bufferSize) async {}

  @override
  Future<LoadedAudio> load(String key, Uint8List wav) async {
    loadedKeys.add(key);
    final int dataSize = wav.length > 44 ? wav.length - 44 : 0;
    final int samples = dataSize ~/ 2;
    _length = Duration(microseconds: (samples * 1000000) ~/ 44100);
    return LoadedAudio(token: _srcCounter++, length: _length);
  }

  @override
  Future<void> unload(LoadedAudio audio) async {
    unloadedTokens.add(audio.token);
  }

  @override
  PlayingVoice playSource(LoadedAudio audio, double volume) {
    _pos = Duration.zero; // 每次播放重置位置。
    return PlayingVoice(token: _handleCounter++); // 正整数 token → isAlive 真。
  }

  @override
  Duration positionOf(PlayingVoice voice) {
    if (keepAlive) return Duration.zero;
    _pos += const Duration(milliseconds: 20); // 每帧推进 20ms。
    return _pos;
  }

  @override
  bool isAlive(PlayingVoice voice) {
    if (keepAlive) return true;
    return _pos < _length;
  }

  @override
  Future<void> stopVoice(PlayingVoice voice) async {}

  @override
  void setGlobalVolume(double volume) {}

  @override
  Future<void> shutdown() async {}
}

/// init 必然失败的假后端（测 T09 验收 4：降级不崩溃）。
class _FailingBackend implements AudioPlayerBackend {
  @override
  Future<void> init(int sampleRate, int bufferSize) async =>
      throw Exception('backend init failed');

  @override
  Future<LoadedAudio> load(String key, Uint8List wav) async =>
      const LoadedAudio(token: 0, length: Duration.zero);

  @override
  Future<void> unload(LoadedAudio audio) async {}

  @override
  PlayingVoice playSource(LoadedAudio audio, double volume) =>
      const PlayingVoice(token: -1);

  @override
  Duration positionOf(PlayingVoice voice) => Duration.zero;

  @override
  bool isAlive(PlayingVoice voice) => false;

  @override
  Future<void> stopVoice(PlayingVoice voice) async {}

  @override
  void setGlobalVolume(double volume) {}

  @override
  Future<void> shutdown() async {}
}

void main() {
  group('AudioPlaybackEvent 防泄露结构护栏（T08 验收 7 / T09）', () {
    test('fieldNames 不含任何音高/频率/MIDI 字段', () {
      expect(AudioPlaybackEvent.fieldNames, isNot(contains('midiNote')));
      expect(AudioPlaybackEvent.fieldNames, isNot(contains('midi')));
      expect(AudioPlaybackEvent.fieldNames, isNot(contains('frequency')));
      expect(AudioPlaybackEvent.fieldNames, isNot(contains('pitch')));
      expect(AudioPlaybackEvent.fieldNames, isNot(contains('hz')));
      // 完整字段集合正确。
      expect(
        AudioPlaybackEvent.fieldNames,
        <String>[
          'type',
          'playbackId',
          'noteIndex',
          'segmentIndex',
          'position',
          'noteDuration',
          'timbre',
          'errorMessage',
        ],
      );
    });

    test('事件工厂方法可构造且不含音高字段', () {
      final AudioPlaybackEvent e = AudioPlaybackEvent.noteStart(
        7,
        noteIndex: 0,
        position: const Duration(milliseconds: 100),
        noteDuration: const Duration(milliseconds: 1100),
        timbre: Timbre.plucked,
      );
      expect(e.playbackId, 7);
      expect(e.noteIndex, 0);
      expect(e.timbre, Timbre.plucked);
    });
  });

  group('FakeAudioService 事件序列（T09 验收 5：虚拟时钟确定性）', () {
    test('初始化后可用', () async {
      final FakeAudioService s = FakeAudioService();
      await s.initialize();
      expect(s.isAvailable, isTrue);
      await s.dispose();
    });

    test('advance 手动推进：sequenceStart→noteStart×2→noteEnd×2→sequenceEnd',
        () async {
      final FakeAudioService s = FakeAudioService()..initialize();
      final List<AudioPlaybackEvent> events = <AudioPlaybackEvent>[];
      final StreamSubscription<AudioPlaybackEvent> sub =
          s.events.listen(events.add);
      final int id = await s.playSequence(_spec());
      s.advance(const Duration(milliseconds: 3000)); // 一次覆盖整段。
      // 广播流异步派发事件（microtask），先 flush 再断言。
      await pumpEventQueue();
      await sub.cancel();
      await s.dispose();

      expect(s.isPlaying, isFalse);
      for (final AudioPlaybackEvent e in events) {
        expect(e.playbackId, id); // 全部归属同一 playbackId。
      }
      expect(events.first.type, AudioEventType.sequenceStart);
      expect(events.last.type, AudioEventType.sequenceEnd);

      final List<AudioPlaybackEvent> noteStarts = events
          .where((AudioPlaybackEvent e) => e.type == AudioEventType.noteStart)
          .toList();
      final List<AudioPlaybackEvent> noteEnds = events
          .where((AudioPlaybackEvent e) => e.type == AudioEventType.noteEnd)
          .toList();
      expect(noteStarts.length, 2);
      expect(noteEnds.length, 2);
      expect(noteStarts[0].noteIndex, 0);
      expect(noteStarts[1].noteIndex, 1);
      expect(noteEnds[0].noteIndex, 0);
      expect(noteEnds[1].noteIndex, 1);
    });

    test('防重叠：新 playSequence 取消旧播放并丢弃旧 id 事件', () async {
      final FakeAudioService s = FakeAudioService()..initialize();
      final List<AudioPlaybackEvent> events = <AudioPlaybackEvent>[];
      final StreamSubscription<AudioPlaybackEvent> sub =
          s.events.listen(events.add);
      final int id1 = await s.playSequence(_spec(root: 60, target: 64));
      s.advance(const Duration(milliseconds: 500));
      final int id2 = await s.playSequence(_spec(root: 62, target: 65));
      s.advance(const Duration(milliseconds: 3000));
      await pumpEventQueue(); // flush 异步事件后再断言。
      await sub.cancel();
      await s.dispose();

      expect(id2, isNot(id1));
      expect(s.currentPlaybackId, id2);
      expect(
        events.any((AudioPlaybackEvent e) =>
            e.type == AudioEventType.cancelled && e.playbackId == id1),
        isTrue,
      );
      final int cancelIdx = events.indexWhere((AudioPlaybackEvent e) =>
          e.type == AudioEventType.cancelled && e.playbackId == id1);
      // cancelled 之前都是 id1，之后不再出现 id1（旧事件被丢弃）。
      for (int i = 0; i < cancelIdx; i++) {
        expect(events[i].playbackId, id1);
      }
      for (int i = cancelIdx + 1; i < events.length; i++) {
        expect(events[i].playbackId, isNot(id1));
      }
    });

    test('确定性：相同 advance 序列产出完全相同事件（无 flaky）', () async {
      Future<List<String>> run() async {
        // 同步跑一轮，收集事件的 (type,noteIndex,segmentIndex) 签名。
        final FakeAudioService s = FakeAudioService()..initialize();
        final List<String> sig = <String>[];
        final StreamSubscription<AudioPlaybackEvent> sub =
            s.events.listen((AudioPlaybackEvent e) {
          sig.add('${e.type.name}:${e.noteIndex}:${e.segmentIndex}');
        });
        await s.playSequence(_spec());
        s.advance(const Duration(milliseconds: 3000));
        await pumpEventQueue(); // flush 异步事件，确保 sig 已完整收集。
        await sub.cancel();
        await s.dispose();
        return sig;
      }

      expect(await run(), await run());
    });

    test('不可用（available=false）时 playSequence 优雅降级为 error 事件', () async {
      final FakeAudioService s = FakeAudioService(available: false)
        ..initialize();
      expect(s.isAvailable, isFalse); // T09 验收 4：降级不崩。
      final List<AudioPlaybackEvent> events = <AudioPlaybackEvent>[];
      final StreamSubscription<AudioPlaybackEvent> sub =
          s.events.listen(events.add);
      final int id = await s.playSequence(_spec());
      await pumpEventQueue(); // flush 异步事件后再断言。
      await sub.cancel();
      await s.dispose();

      expect(id, greaterThan(0)); // 仍返回合法 id。
      // 关键：发出 error 事件、不崩溃（降级路径）。
      expect(
        events.any((AudioPlaybackEvent e) =>
            e.type == AudioEventType.error && e.playbackId == id),
        isTrue,
      );
    });
  });

  group('SoLoudAudioService 接口与降级（T09 验收 1/4）', () {
    testWidgets('两种实现均 implements AudioService 接口',
        (WidgetTester tester) async {
      final SoLoudAudioService soloud =
          SoLoudAudioService(backend: _FakeBackend());
      expect(soloud, isA<AudioService>());
      await soloud.dispose();
      expect(FakeAudioService(), isA<AudioService>());
    });

    testWidgets('initialize 失败 → isAvailable=false，playSequence 不崩溃（降级）',
        (WidgetTester tester) async {
      final SoLoudAudioService s =
          SoLoudAudioService(backend: _FailingBackend());
      await s.initialize();
      expect(s.isAvailable, isFalse); // T09 验收 4：降级不崩。
      final int id = await s.playSequence(_spec());
      expect(id, greaterThan(0)); // 仍返回合法 id。
      await s.dispose();
    });
  });

  group('SoLoudAudioService 防重叠与 Ticker 停止（T09 验收 2/3）', () {
    test('不同序列使用不同 L3 键，不会串用第一道题音频', () async {
      final _FakeBackend backend = _FakeBackend();
      final SoLoudAudioService service = SoLoudAudioService(backend: backend);
      await service.initialize();
      await service.playSequence(_spec(root: 60, target: 64));
      await service.playSequence(_spec(root: 62, target: 67));

      expect(backend.loadedKeys, hasLength(2));
      expect(backend.loadedKeys[0], isNot(backend.loadedKeys[1]));
      await service.dispose();
    });

    test('L3 淘汰与 dispose 都会卸载原生音源', () async {
      final _FakeBackend backend = _FakeBackend();
      final AudioBufferCache cache = AudioBufferCache(
        backend: backend,
        loadedCapacity: 1,
      );
      final SoLoudAudioService service = SoLoudAudioService(
        backend: backend,
        cache: cache,
      );
      await service.initialize();
      await service.playSequence(_spec(root: 60, target: 64));
      await service.playSequence(_spec(root: 62, target: 67));
      await pumpEventQueue();
      expect(backend.unloadedTokens, hasLength(1));

      await service.dispose();
      expect(backend.unloadedTokens, hasLength(2));
    });

    test('防重叠：新 playSequence 停旧并丢弃旧 id 事件', () async {
      // 用普通 test（非 testWidgets）：本测试只验证服务层「新播放取消旧播放、旧 id
      // 事件被丢弃」的逻辑，不需要 WidgetTester，也不应驱动 Ticker。若用 testWidgets，
      // 收尾的 pumpAndSettle 会因 SoLoudAudioService 仍活跃的 Ticker 死循环（整包运行
      // 时会 hang，单文件运行偶发通过）——此处刻意避免该路径。
      final _FakeBackend backend = _FakeBackend(keepAlive: false);
      final SoLoudAudioService s = SoLoudAudioService(
        backend: backend,
        cache: AudioBufferCache(backend: backend),
      );
      await s.initialize();
      final List<AudioPlaybackEvent> events = <AudioPlaybackEvent>[];
      final StreamSubscription<AudioPlaybackEvent> sub =
          s.events.listen(events.add);
      final int id1 = await s.playSequence(_spec(root: 60, target: 64));
      final int id2 = await s.playSequence(_spec(root: 62, target: 65));
      // 广播流异步派发事件（microtask），先 flush 再断言。
      await pumpEventQueue();
      await sub.cancel();
      await s.dispose();

      expect(id2, isNot(id1));
      expect(s.currentPlaybackId, id2);
      expect(
        events.any((AudioPlaybackEvent e) =>
            e.type == AudioEventType.cancelled && e.playbackId == id1),
        isTrue,
      );
      final int cancelIdx = events.indexWhere((AudioPlaybackEvent e) =>
          e.type == AudioEventType.cancelled && e.playbackId == id1);
      for (int i = cancelIdx + 1; i < events.length; i++) {
        expect(events[i].playbackId, isNot(id1)); // 旧 id 事件被丢弃。
      }
    });

    test('Ticker 播放结束必须停（无泄漏）', () async {
      // 用普通 test（非 testWidgets）：testWidgets 收尾的 pumpAndSettle 会在仍有活跃
      // Ticker 帧回调时死循环（整包运行会 hang）。此处直接在普通 test 下手动泵帧驱动
      // Ticker（SchedulerBinding.handleBeginFrame/DrawFrame），循环有上界，绝不阻塞。
      final _FakeBackend backend = _FakeBackend(keepAlive: false);
      final SoLoudAudioService s = SoLoudAudioService(
        backend: backend,
        cache: AudioBufferCache(backend: backend),
      );
      await s.initialize();
      final List<AudioPlaybackEvent> events = <AudioPlaybackEvent>[];
      final StreamSubscription<AudioPlaybackEvent> sub =
          s.events.listen(events.add);
      final int id = await s.playSequence(_spec(
        root: 60,
        target: 64,
        noteDuration: const Duration(milliseconds: 100),
        noteGap: const Duration(milliseconds: 20),
      ));
      // 播放中 Ticker 应已启动（isPlaying=true）。
      expect(s.isPlaying, isTrue);

      // 手动驱动帧：Ticker 在 SchedulerBinding 上注册了 transient 回调，每次
      // handleBeginFrame 触发 _onTick（positionOf 每帧 +20ms），到达序列末尾时
      // _onTick 调用 _stopTicker，isPlaying 翻回 false。循环上界 1000 帧兜底。
      final SchedulerBinding binding = SchedulerBinding.instance;
      int frame = 0;
      while (s.isPlaying && frame < 1000) {
        binding.handleBeginFrame(Duration(milliseconds: frame * 16));
        binding.handleDrawFrame();
        frame++;
      }
      // 广播流异步派发事件（microtask），先 flush 再断言。
      await pumpEventQueue();
      await sub.cancel();
      await s.dispose();

      expect(s.isPlaying, isFalse); // Ticker 已停（无泄漏，T09 验收 3）。
      expect(
        events.any((AudioPlaybackEvent e) =>
            e.type == AudioEventType.sequenceEnd && e.playbackId == id),
        isTrue,
      );
    });
  });
}
