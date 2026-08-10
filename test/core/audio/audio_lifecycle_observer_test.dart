// T23 验收 ①：应用退到后台 / 隐藏 / 销毁时立即停音频。
//
// 本文件锁定 [AudioLifecycleObserver] 作为「什么时候该停音频」的唯一判定口径：
// 状态集合、幂等的 attach/detach、以及「停音频失败不能把异常抛到退出路径上」。
// 全程用 [FakeAudioService]，不碰任何原生音频引擎。

import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/audio/audio_lifecycle_observer.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';

/// 记录 `stop()` 调用次数的音频替身。
class _CountingAudio extends FakeAudioService {
  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls++;
    await super.stop();
  }
}

/// `stop()` 必定抛异常的音频替身（模拟引擎已崩）。
class _ThrowingAudio extends FakeAudioService {
  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls++;
    throw StateError('audio engine down');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shouldStop 判定口径', () {
    test('backgroundStates 恰好是 paused / hidden / detached 三态', () {
      expect(
        AudioLifecycleObserver.backgroundStates,
        <AppLifecycleState>{
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.detached,
        },
      );
    });

    test('后台三态一律返回 true', () {
      expect(AudioLifecycleObserver.shouldStop(AppLifecycleState.paused), isTrue);
      expect(AudioLifecycleObserver.shouldStop(AppLifecycleState.hidden), isTrue);
      expect(
        AudioLifecycleObserver.shouldStop(AppLifecycleState.detached),
        isTrue,
      );
    });

    test('resumed / inactive 不停音频', () {
      // inactive 在 macOS 上仅仅是失去焦点（切个窗口），停音频会很突兀。
      expect(
        AudioLifecycleObserver.shouldStop(AppLifecycleState.resumed),
        isFalse,
      );
      expect(
        AudioLifecycleObserver.shouldStop(AppLifecycleState.inactive),
        isFalse,
      );
    });
  });

  group('handle / stopNow', () {
    test('paused 触发一次 stop', () async {
      final _CountingAudio audio = _CountingAudio();
      final AudioLifecycleObserver observer = AudioLifecycleObserver(audio);
      await observer.handle(AppLifecycleState.paused);
      expect(audio.stopCalls, 1);
    });

    test('hidden / detached 同样触发 stop', () async {
      final _CountingAudio audio = _CountingAudio();
      final AudioLifecycleObserver observer = AudioLifecycleObserver(audio);
      await observer.handle(AppLifecycleState.hidden);
      await observer.handle(AppLifecycleState.detached);
      expect(audio.stopCalls, 2);
    });

    test('resumed 不触发 stop', () async {
      final _CountingAudio audio = _CountingAudio();
      final AudioLifecycleObserver observer = AudioLifecycleObserver(audio);
      await observer.handle(AppLifecycleState.resumed);
      expect(audio.stopCalls, 0);
    });

    test('stop 抛异常时被吞掉，不污染退出路径', () async {
      final _ThrowingAudio audio = _ThrowingAudio();
      final AudioLifecycleObserver observer = AudioLifecycleObserver(audio);
      await expectLater(observer.stopNow(), completes);
      expect(audio.stopCalls, 1);
    });
  });

  group('attach / detach 幂等', () {
    test('重复 attach 只注册一次，detach 后可再 attach', () {
      final _CountingAudio audio = _CountingAudio();
      final AudioLifecycleObserver observer = AudioLifecycleObserver(audio);
      expect(observer.isAttached, isFalse);

      observer
        ..attach()
        ..attach();
      expect(observer.isAttached, isTrue);

      observer
        ..detach()
        ..detach();
      expect(observer.isAttached, isFalse);

      observer.attach();
      expect(observer.isAttached, isTrue);
      observer.detach();
    });

    test('已注册时收到 paused 会停音频', () async {
      final _CountingAudio audio = _CountingAudio();
      final AudioLifecycleObserver observer = AudioLifecycleObserver(audio)
        ..attach();
      addTearDown(observer.detach);

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      // didChangeAppLifecycleState 内部是 unawaited，让出一次事件循环再断言。
      await Future<void>.delayed(Duration.zero);
      expect(audio.stopCalls, 1);
    });
  });
}
