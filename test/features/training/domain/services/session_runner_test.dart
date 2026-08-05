// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/utils/deterministic_random.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/services/session_runner.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// T06 验收 §5.7：会话运行器——作答、统计累积、加练插题、章节推进。
void main() {
  final start = DateTime.utc(2026, 6, 1, 10);

  TrainingConfig config() => TrainingConfig(
        enabledIntervals: IntervalCatalog.trainableIds,
        questionCount: 10,
        answerMode: AnswerMode.enabledOnly,
      );

  IntervalId wrongPick(IntervalId correct) =>
      correct == IntervalId.perfectOctave
          ? IntervalId.minorSecond
          : IntervalId.perfectOctave;

  test('全对：会话结算、accuracy=1、连击=题数', () {
    final runner = SessionRunner.start(
      config: config(),
      priorSnapshot: StatsSnapshot.empty(),
      random: Xorshift32Random(seed: 42),
      now: start,
    );
    var t = start;
    while (runner.hasNext) {
      final q = runner.currentQuestion!;
      t = t.add(const Duration(seconds: 1));
      runner.answer(
        selectedInterval: q.correctInterval,
        isUncertain: false,
        replayCount: 0,
        responseDuration: const Duration(milliseconds: 500),
        now: t,
      );
    }
    expect(runner.isFinished, isTrue);
    expect(runner.accuracy, 1.0);
    expect(runner.session.maxCombo, 10);
    expect(runner.extraDrillCount, 0);
    expect(runner.session.correctCount, 10);
    expect(runner.questions.length, 10);
  });

  test('答错触发加练插题（extraDrillCount = 3）', () {
    final runner = SessionRunner.start(
      config: config(),
      priorSnapshot: StatsSnapshot.empty(),
      random: Xorshift32Random(seed: 42),
      now: start,
    );
    var t = start;
    var firstWrongDone = false;
    var insertedSeen = 0;
    while (runner.hasNext) {
      final q = runner.currentQuestion!;
      t = t.add(const Duration(seconds: 1));
      final isFirst = !firstWrongDone && runner.completedCount == 0;
      if (isFirst) {
        firstWrongDone = true;
        runner.answer(
          selectedInterval: wrongPick(q.correctInterval),
          isUncertain: false,
          replayCount: 1,
          responseDuration: const Duration(milliseconds: 800),
          now: t,
        );
        insertedSeen = runner.extraDrillCount;
      } else {
        runner.answer(
          selectedInterval: q.correctInterval,
          isUncertain: false,
          replayCount: 0,
          responseDuration: const Duration(milliseconds: 500),
          now: t,
        );
      }
    }
    expect(insertedSeen, 3, reason: '答错后应立即插入 3 道加练');
    expect(runner.extraDrillCount, 3);
    expect(runner.questions.length, 13, reason: '10 计划 + 3 加练');
    expect(runner.isFinished, isTrue);
    // 加练题答错不再递归（连击归零但不再插入）。
    expect(runner.extraDrillCount, 3);
  });

  test('updatedSnapshot 反映本次作答', () {
    final prior = StatsSnapshot.empty();
    final runner = SessionRunner.start(
      config: config(),
      priorSnapshot: prior,
      random: Xorshift32Random(seed: 42),
      now: start,
    );
    var t = start;
    while (runner.hasNext) {
      final q = runner.currentQuestion!;
      t = t.add(const Duration(seconds: 1));
      runner.answer(
        selectedInterval: q.correctInterval,
        isUncertain: false,
        replayCount: 0,
        responseDuration: const Duration(milliseconds: 400),
        now: t,
      );
    }
    final snap = runner.updatedSnapshot;
    expect(snap.totalQuestions, greaterThanOrEqualTo(10));
    expect(snap.totalSessions, 1);
    // 增量叠加与全量重算一致。
    final rebuilt = StatsSnapshot.rebuildFromAttempts(
      runner.attempts,
      <TrainingSession>[runner.session],
    );
    expect(rebuilt.totalQuestions, snap.totalQuestions);
    expect(rebuilt.overallAccuracy(), closeTo(snap.overallAccuracy(), 1e-12));
  });

  test('已结算后再次 answer 抛 StateError', () {
    final runner = SessionRunner.start(
      config: config(),
      priorSnapshot: StatsSnapshot.empty(),
      random: Xorshift32Random(seed: 42),
      now: start,
    );
    var t = start;
    while (runner.hasNext) {
      final q = runner.currentQuestion!;
      t = t.add(const Duration(seconds: 1));
      runner.answer(
        selectedInterval: q.correctInterval,
        isUncertain: false,
        replayCount: 0,
        responseDuration: const Duration(milliseconds: 300),
        now: t,
      );
    }
    expect(
      () => runner.answer(
        selectedInterval: IntervalId.minorThird,
        isUncertain: false,
        replayCount: 0,
        responseDuration: const Duration(milliseconds: 300),
        now: t,
      ),
      throwsStateError,
    );
  });

  group('shouldAdvanceChapter（§5.7）', () {
    TrainingSession finishedSession({
      required String presetId,
      required int correct,
      required int total,
      required DateTime finishedAt,
    }) =>
        TrainingSession(
          sessionId: 's-$presetId-$correct',
          trainingMode: TrainingMode.daily,
          startedAt: finishedAt.subtract(const Duration(minutes: 5)),
          finishedAt: finishedAt,
          totalQuestions: total,
          completedQuestions: total,
          correctCount: correct,
          configSnapshot: TrainingConfig.defaults,
          presetId: presetId,
        );

    test('不少于 2 个历史会话时判否', () {
      final sessions = <TrainingSession>[
        finishedSession(
          presetId: 'basic',
          correct: 18,
          total: 20,
          finishedAt: start,
        ),
      ];
      expect(
        SessionRunner.shouldAdvanceChapter(sessions, presetId: 'basic'),
        isFalse,
      );
    });

    test('最近 2 次均值 ≥ 0.85 且同预设 → 允许推进', () {
      final sessions = <TrainingSession>[
        finishedSession(
          presetId: 'basic',
          correct: 17,
          total: 20,
          finishedAt: start,
        ),
        finishedSession(
          presetId: 'basic',
          correct: 18,
          total: 20,
          finishedAt: start.add(const Duration(days: 1)),
        ),
        // 另一个预设不应计入。
        finishedSession(
          presetId: 'other',
          correct: 0,
          total: 20,
          finishedAt: start.add(const Duration(days: 2)),
        ),
      ];
      expect(
        SessionRunner.shouldAdvanceChapter(sessions, presetId: 'basic'),
        isTrue,
      );
    });

    test('均值低于 0.85 不推进', () {
      final sessions = <TrainingSession>[
        finishedSession(
          presetId: 'basic',
          correct: 14,
          total: 20,
          finishedAt: start,
        ),
        finishedSession(
          presetId: 'basic',
          correct: 14,
          total: 20,
          finishedAt: start.add(const Duration(days: 1)),
        ),
      ];
      expect(
        SessionRunner.shouldAdvanceChapter(sessions, presetId: 'basic'),
        isFalse,
      );
    });
  });

  test('二选一焦点对运行器产出全为二选一', () {
    final pair = IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth);
    final runner = SessionRunner.start(
      config: config().copyWith(
        answerMode: AnswerMode.binary,
        enabledIntervals: pair.toSet(),
      ),
      priorSnapshot: StatsSnapshot.empty(),
      random: Xorshift32Random(seed: 42),
      now: start,
      focusPair: pair,
      trainingMode: TrainingMode.binaryDrill,
    );
    var t = start;
    while (runner.hasNext) {
      final q = runner.currentQuestion!;
      t = t.add(const Duration(seconds: 1));
      runner.answer(
        selectedInterval: q.correctInterval,
        isUncertain: false,
        replayCount: 0,
        responseDuration: const Duration(milliseconds: 400),
        now: t,
      );
    }
    for (final q in runner.questions) {
      expect(q.isBinary, isTrue);
    }
    expect(runner.session.trainingMode, TrainingMode.binaryDrill);
  });
}
