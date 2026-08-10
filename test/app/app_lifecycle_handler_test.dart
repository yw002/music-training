// T23 验收 ① + ⑥：进程级生命周期收尾。
//
// 覆盖点：
// - 退到后台 / 关窗 → 停音频 → （有进行中会话则标 aborted 落盘）→ flush；
// - `handleShutdown` 幂等（Windows 关窗双重保险不会重复落盘）；
// - 已结算 / 已标记的会话不重复 abort；
// - [ActiveSessionRegistry] 的登记与清除语义；
// - 仓储抛异常时不把异常抛到退出路径上。
//
// 全程用内存替身，不触任何文件系统与原生音频。

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/app_lifecycle_handler.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/repositories/recovery_report.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 记录 `stop()` 次数的音频替身。
class _CountingAudio extends FakeAudioService {
  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls++;
    await super.stop();
  }
}

/// 记录调用的训练仓储替身。
///
/// 只有 [abortSession] / [flush] 会被 [AppLifecycleHandler] 用到，其余方法给出
/// 最小可用实现（不抛 `UnimplementedError`，避免误报把测试引偏）。
class _RecordingRepository implements TrainingRepository {
  int abortCalls = 0;
  int flushCalls = 0;
  TrainingSession? abortedSession;

  /// 非空时 [flush] 会一直挂起到它被 complete（用于验证幂等）。
  Completer<void>? flushGate;

  /// 为真时 [abortSession] / [flush] 抛异常。
  bool throwOnWrite = false;

  final StreamController<StatsSnapshot> _stats =
      StreamController<StatsSnapshot>.broadcast();

  @override
  Future<void> abortSession(TrainingSession session) async {
    abortCalls++;
    abortedSession = session;
    if (throwOnWrite) {
      throw StateError('disk full');
    }
  }

  @override
  Future<void> flush() async {
    flushCalls++;
    if (throwOnWrite) {
      throw StateError('disk full');
    }
    final Completer<void>? gate = flushGate;
    if (gate != null) {
      await gate.future;
    }
  }

  @override
  Future<void> startSession(TrainingSession session) async {}

  @override
  Future<void> recordAttempt(TrainingAttempt attempt) async {}

  @override
  Future<void> finishSession(TrainingSession session) async {}

  @override
  Future<StatsSnapshot> loadStats() async => StatsSnapshot.empty();

  @override
  Stream<StatsSnapshot> get statsChanges => _stats.stream;

  @override
  Future<List<TrainingSession>> recentSessions(int limit) async =>
      const <TrainingSession>[];

  @override
  Future<List<TrainingAttempt>> attemptsInRange(DateTime from, DateTime to) async =>
      const <TrainingAttempt>[];

  @override
  Future<RecoveryReport?> takeRecoveryReport() async => null;

  @override
  Future<void> clearAll() async {}

  @override
  Future<String> exportJson() async => '{}';

  @override
  Future<void> importJson(String json) async {}
}

TrainingSession _session({
  String id = 's1',
  DateTime? finishedAt,
  bool aborted = false,
  int completed = 3,
}) =>
    TrainingSession(
      sessionId: id,
      trainingMode: TrainingMode.daily,
      startedAt: DateTime.utc(2024, 5, 1, 10),
      totalQuestions: 10,
      completedQuestions: completed,
      correctCount: completed,
      configSnapshot: TrainingConfig.defaults,
      finishedAt: finishedAt,
      aborted: aborted,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActiveSessionRegistry', () {
    test('初始为空', () {
      final ActiveSessionRegistry registry = ActiveSessionRegistry();
      expect(registry.current, isNull);
      expect(registry.hasActiveSession, isFalse);
    });

    test('begin 后有进行中会话，update 覆盖，clear 清空', () {
      final ActiveSessionRegistry registry = ActiveSessionRegistry()
        ..begin(_session(completed: 0));
      expect(registry.hasActiveSession, isTrue);
      expect(registry.current!.completedQuestions, 0);

      registry.update(_session(completed: 5));
      expect(registry.current!.completedQuestions, 5);

      registry.clear();
      expect(registry.current, isNull);
      expect(registry.hasActiveSession, isFalse);
    });

    test('已结算的会话不算「进行中」', () {
      final ActiveSessionRegistry registry = ActiveSessionRegistry()
        ..begin(_session(finishedAt: DateTime.utc(2024, 5, 1, 10, 8)));
      expect(registry.current, isNotNull);
      expect(registry.hasActiveSession, isFalse);
    });
  });

  group('handleShutdown 收尾顺序', () {
    test('无进行中会话：只停音频 + flush，不写 aborted', () async {
      final _CountingAudio audio = _CountingAudio();
      final _RecordingRepository repo = _RecordingRepository();
      final AppLifecycleHandler handler = AppLifecycleHandler(
        audio: audio,
        repository: repo,
      );

      await handler.handleShutdown();

      expect(audio.stopCalls, 1);
      expect(repo.abortCalls, 0);
      expect(repo.flushCalls, 1);
    });

    test('有进行中会话：标记 aborted 落盘并清空登记（验收 ⑥）', () async {
      final _CountingAudio audio = _CountingAudio();
      final _RecordingRepository repo = _RecordingRepository();
      final ActiveSessionRegistry sessions = ActiveSessionRegistry()
        ..begin(_session(completed: 4));
      final AppLifecycleHandler handler = AppLifecycleHandler(
        audio: audio,
        repository: repo,
        sessions: sessions,
      );

      await handler.handleShutdown();

      expect(audio.stopCalls, 1);
      expect(repo.abortCalls, 1);
      expect(repo.abortedSession, isNotNull);
      expect(repo.abortedSession!.aborted, isTrue);
      // 进度被原样保留，方便事后排查「中断在第几题」。
      expect(repo.abortedSession!.completedQuestions, 4);
      // 未结算：不会被 StatsSnapshot 计入。
      expect(repo.abortedSession!.isFinished(), isFalse);
      expect(repo.flushCalls, 1);
      expect(sessions.current, isNull);
    });

    test('已结算的会话不再 abort', () async {
      final _RecordingRepository repo = _RecordingRepository();
      final ActiveSessionRegistry sessions = ActiveSessionRegistry()
        ..begin(_session(finishedAt: DateTime.utc(2024, 5, 1, 10, 8)));
      final AppLifecycleHandler handler = AppLifecycleHandler(
        audio: _CountingAudio(),
        repository: repo,
        sessions: sessions,
      );

      await handler.handleShutdown();

      expect(repo.abortCalls, 0);
      expect(repo.flushCalls, 1);
      expect(sessions.current, isNull);
    });

    test('已标记 aborted 的会话不重复落盘', () async {
      final _RecordingRepository repo = _RecordingRepository();
      final ActiveSessionRegistry sessions = ActiveSessionRegistry()
        ..begin(_session(aborted: true));
      final AppLifecycleHandler handler = AppLifecycleHandler(
        audio: _CountingAudio(),
        repository: repo,
        sessions: sessions,
      );

      await handler.handleShutdown();

      expect(repo.abortCalls, 0);
      expect(sessions.current, isNull);
    });

    test('仓储抛异常时不冒泡，flush 仍会被尝试', () async {
      final _RecordingRepository repo = _RecordingRepository()
        ..throwOnWrite = true;
      final ActiveSessionRegistry sessions = ActiveSessionRegistry()
        ..begin(_session());
      final AppLifecycleHandler handler = AppLifecycleHandler(
        audio: _CountingAudio(),
        repository: repo,
        sessions: sessions,
      );

      await expectLater(handler.handleShutdown(), completes);
      expect(repo.abortCalls, 1);
      expect(repo.flushCalls, 1);
    });
  });

  group('幂等（Windows 关窗双重保险）', () {
    test('并发两次 handleShutdown 只真正执行一次', () async {
      final _CountingAudio audio = _CountingAudio();
      final _RecordingRepository repo = _RecordingRepository()
        ..flushGate = Completer<void>();
      final ActiveSessionRegistry sessions = ActiveSessionRegistry()
        ..begin(_session());
      final AppLifecycleHandler handler = AppLifecycleHandler(
        audio: audio,
        repository: repo,
        sessions: sessions,
      );

      // 第一路：window_manager 的 onWindowClose。
      final Future<void> first = handler.handleShutdown();
      // 第二路：WidgetsBinding 的 hidden。此时第一路还卡在 flush 上。
      final Future<void> second = handler.handleShutdown();
      expect(identical(first, second), isTrue);

      repo.flushGate!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(audio.stopCalls, 1);
      expect(repo.abortCalls, 1);
      expect(repo.flushCalls, 1);
    });

    test('上一次完成后可以再次执行（进程未退出时的第二轮后台切换）', () async {
      final _CountingAudio audio = _CountingAudio();
      final _RecordingRepository repo = _RecordingRepository();
      final AppLifecycleHandler handler = AppLifecycleHandler(
        audio: audio,
        repository: repo,
      );

      await handler.handleShutdown();
      await handler.handleShutdown();

      expect(audio.stopCalls, 2);
      expect(repo.flushCalls, 2);
    });
  });

  group('WidgetsBindingObserver 接线', () {
    test('attach / detach 幂等', () {
      final AppLifecycleHandler handler = AppLifecycleHandler(
        audio: _CountingAudio(),
        repository: _RecordingRepository(),
      );
      expect(handler.isAttached, isFalse);

      handler
        ..attach()
        ..attach();
      expect(handler.isAttached, isTrue);

      handler
        ..detach()
        ..detach();
      expect(handler.isAttached, isFalse);
    });

    test('paused 触发收尾，resumed 不触发', () async {
      final _CountingAudio audio = _CountingAudio();
      final _RecordingRepository repo = _RecordingRepository();
      final AppLifecycleHandler handler = AppLifecycleHandler(
        audio: audio,
        repository: repo,
      )..attach();
      addTearDown(handler.detach);

      handler.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(repo.flushCalls, 0);

      handler.didChangeAppLifecycleState(AppLifecycleState.paused);
      // 收尾链路是 unawaited 的三段 await，多让几拍确保跑完。
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(audio.stopCalls, 1);
      expect(repo.flushCalls, 1);
    });
  });
}
