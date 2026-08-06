// TrainingCubit 状态机（T10 验收 2/3/5/6 + StatsSnapshot.empty 可用性）。
//
// 使用 mocktail 的 MockTrainingRepository 隔离落盘，FakeAudioService + 虚拟时钟驱动
// 播放事件（架构 §7 共享知识：UI 测试用 FakeAudioService + 虚拟时钟）。
//
// 覆盖点：
//  - 状态机 idle→loading→ready→playing→awaitingAnswer→answered→next…→finished；
//  - submitAnswer / submitUncertain / replay / next / abort 全部可用且不崩溃；
//  - combo 逻辑：答对 +1，答错清零，uncertain 不变（§5.7）；
//  - 未 start（无 runner）时所有动作是安全 no-op（不崩溃）；
//  - StatsSnapshot.empty() 可由 finished 态安全持有。

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_cubit.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_state.dart';

class MockTrainingRepository extends Mock implements TrainingRepository {}

TrainingConfig _config() => TrainingConfig(
      enabledIntervals: <IntervalId>{
        IntervalId.minorSecond,
        IntervalId.majorSeventh,
      },
      questionCount: 5,
      answerMode: AnswerMode.enabledOnly,
    );

TrainingCubit _build(MockTrainingRepository repo, FakeAudioService audio) =>
    TrainingCubit(
      config: _config(),
      repository: repo,
      audio: audio,
      settings: AppSettings.defaults,
      random: math.Random(42),
      clock: () => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

void _stubRepo(MockTrainingRepository repo) {
  when(() => repo.loadStats()).thenAnswer((_) async => StatsSnapshot.empty());
  when(() => repo.startSession(any())).thenAnswer((_) async {});
  when(() => repo.recordAttempt(any())).thenAnswer((_) async {});
  when(() => repo.finishSession(any())).thenAnswer((_) async {});
  when(() => repo.recentSessions(any())).thenAnswer((_) async => <TrainingSession>[]);
  when(() => repo.flush()).thenAnswer((_) async {});
  when(() => repo.statsChanges).thenAnswer((_) => const Stream<StatsSnapshot>.empty());
}

/// 驱动到 awaitingAnswer：start → 推进虚拟时钟触发 sequenceEnd → awaiting。
Future<void> _driveToAwaiting(TrainingCubit cubit, FakeAudioService audio) async {
  await cubit.start();
  audio.advance(const Duration(seconds: 3));
  await pumpEventQueue();
  await pumpEventQueue();
}

void main() {
  group('TrainingCubit 状态机（T10）', () {
    late MockTrainingRepository repo;
    late FakeAudioService audio;

    setUp(() {
      // 必须在任何 `when(... any())` 之前注册 fallback，否则 mocktail 抛
      // "registerFallbackValue was not previously called"。
      registerFallbackValue(TrainingSession(
        sessionId: '',
        trainingMode: TrainingMode.daily,
        startedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        totalQuestions: 0,
        configSnapshot: _config(),
      ));
      registerFallbackValue(StatsSnapshot.empty());
      registerFallbackValue(TrainingAttempt(
        attemptId: '',
        sessionId: '',
        questionId: '',
        correctInterval: IntervalId.minorSecond,
        selectedInterval: IntervalId.majorSecond,
        isUncertain: false,
        replayCount: 0,
        responseDuration: Duration.zero,
        direction: PlaybackDirection.ascending,
        timbre: Timbre.keyboard,
        rootMode: RootMode.limitedRandom,
        rootMidiNote: 60,
        answerMode: AnswerMode.enabledOnly,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ));
      repo = MockTrainingRepository();
      _stubRepo(repo);
      audio = FakeAudioService()..initialize();
    });

    tearDown(() async {
      await audio.dispose();
    });

    test('完整流程：loading→ready→playing→awaiting→answered→next…→finished', () async {
      final cubit = _build(repo, audio);
      final states = <TrainingState>[];
      final sub = cubit.stream.listen(states.add);

      await _driveToAwaiting(cubit, audio);
      expect(cubit.state, isA<TrainingAwaitingAnswer>());

      for (var i = 0; i < 5; i++) {
        final awaiting = cubit.state as TrainingAwaitingAnswer;
        await cubit.submitAnswer(awaiting.question.correctInterval);
        final answered = cubit.state as TrainingAnswered;
        expect(answered.isCorrect, isTrue);
        await cubit.next();
        if (!answered.isLast) {
          audio.advance(const Duration(seconds: 3));
          await pumpEventQueue();
        }
      }
      // 末题 next() 对 _finish() 是 fire-and-forget，等其落盘 + 章节判定完成。
      await pumpEventQueue();
      await pumpEventQueue();

      expect(cubit.state, isA<TrainingFinished>());
      // 关键中间态都出现过。
      expect(states.any((s) => s is TrainingLoading), isTrue);
      expect(states.any((s) => s is TrainingReady), isTrue);
      expect(states.any((s) => s is TrainingPlaying), isTrue);
      expect(states.any((s) => s is TrainingAwaitingAnswer), isTrue);
      expect(states.any((s) => s is TrainingAnswered), isTrue);

      await sub.cancel();
      await cubit.close();
    });

    test('submitUncertain：标记为不确定，combo 不变', () async {
      final cubit = _build(repo, audio);
      await _driveToAwaiting(cubit, audio);
      final comboBefore =
          (cubit.state as TrainingAwaitingAnswer).combo;
      await cubit.submitUncertain();
      final answered = cubit.state as TrainingAnswered;
      expect(answered.isUncertain, isTrue);
      expect(answered.attempt.isCorrect, isFalse);
      expect(answered.combo, comboBefore);
      await cubit.close();
    });

    test('replay 仅 awaiting 且可重播时生效（replayCount+1，重新播放）', () async {
      final cubit = _build(repo, audio);
      await _driveToAwaiting(cubit, audio);
      final before =
          (cubit.state as TrainingAwaitingAnswer).replayCount;
      cubit.replay();
      // replay 触发重播：等 playSequence 的 .then 把 _playbackId 置新，再推进虚拟时钟
      // 发 sequenceEnd，状态机才会以新的 replayCount 重新进入 awaiting。
      await pumpEventQueue();
      audio.advance(const Duration(seconds: 3));
      await pumpEventQueue();
      final after = cubit.state as TrainingAwaitingAnswer;
      expect(after.replayCount, before + 1);
      await cubit.close();
    });

    test('combo 逻辑：答对+1，答错清零，uncertain 不变（§5.7）', () async {
      final cubit = _build(repo, audio);
      final states = <TrainingState>[];
      final sub = cubit.stream.listen(states.add);
      await _driveToAwaiting(cubit, audio);

      // 第 1 题答对 → combo 1
      var awaiting = cubit.state as TrainingAwaitingAnswer;
      await cubit.submitAnswer(awaiting.question.correctInterval);
      await cubit.next();
      audio.advance(const Duration(seconds: 3));
      await pumpEventQueue();
      awaiting = cubit.state as TrainingAwaitingAnswer;
      expect(awaiting.combo, 1);

      // 第 2 题答对 → combo 2
      await cubit.submitAnswer(awaiting.question.correctInterval);
      await cubit.next();
      audio.advance(const Duration(seconds: 3));
      await pumpEventQueue();
      awaiting = cubit.state as TrainingAwaitingAnswer;
      expect(awaiting.combo, 2);

      // 第 3 题答错（选一个非正确的音程）→ combo 清零
      final wrong = awaiting.question.correctInterval == IntervalId.minorSecond
          ? IntervalId.majorSeventh
          : IntervalId.minorSecond;
      await cubit.submitAnswer(wrong);
      await cubit.next();
      audio.advance(const Duration(seconds: 3));
      await pumpEventQueue();
      awaiting = cubit.state as TrainingAwaitingAnswer;
      expect(awaiting.combo, 0);

      // 第 4 题 uncertain → combo 不变（仍 0）
      await cubit.submitUncertain();
      await cubit.next();
      audio.advance(const Duration(seconds: 3));
      await pumpEventQueue();
      awaiting = cubit.state as TrainingAwaitingAnswer;
      expect(awaiting.combo, 0);

      await sub.cancel();
      await cubit.close();
    });

    test('未 start（无 runner）时 submitAnswer/replay/next/abort 均为安全 no-op', () async {
      final cubit = _build(repo, audio);
      expect(cubit.state, isA<TrainingInitial>());

      await cubit.submitAnswer(IntervalId.minorSecond);
      cubit.replay();
      await cubit.next();
      await cubit.abort();

      // 不崩溃，且仍处于初始态。
      expect(cubit.state, isA<TrainingInitial>());
      await cubit.close();
    });

    test('finished 态安全持有有效快照（不崩溃，含全部作答统计）', () async {
      final cubit = _build(repo, audio);
      await _driveToAwaiting(cubit, audio);
      // 一路答对直到 finished（5 题，全对不触发加练，故正好 5 题）。
      for (var i = 0; i < 5; i++) {
        final awaiting = cubit.state as TrainingAwaitingAnswer;
        await cubit.submitAnswer(awaiting.question.correctInterval);
        final answered = cubit.state as TrainingAnswered;
        await cubit.next();
        if (!answered.isLast) {
          audio.advance(const Duration(seconds: 3));
          await pumpEventQueue();
        }
      }
      // next() 对末题调用 _finish() 是 fire-and-forget（不 await），需等其落盘 +
      // 章节判定完成才会 emit TrainingFinished。
      await pumpEventQueue();
      await pumpEventQueue();
      final finished = cubit.state as TrainingFinished;
      // 有 runner 时结算态持有「本会话累加出的真实快照」，而非空兜底。
      expect(finished.snapshot, isA<StatsSnapshot>());
      expect(finished.snapshot.isEmpty, isFalse);
      expect(finished.snapshot.totalQuestions, 5);
      await cubit.close();
    });
  });
}
