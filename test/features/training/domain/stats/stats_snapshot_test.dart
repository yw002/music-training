// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/stats/daily_summary.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// T05 验收：统计聚合 + 混淆矩阵 + JSON 往返 + 增量与重算一致。
void main() {
  final base = DateTime.utc(2026, 3, 10, 8);

  TrainingAttempt attempt({
    required IntervalId correct,
    IntervalId? selected,
    bool uncertain = false,
    int replays = 0,
    int ms = 1000,
    DateTime? at,
    String? focusPair,
    PlaybackDirection direction = PlaybackDirection.ascending,
    Timbre timbre = Timbre.keyboard,
    RootMode rootMode = RootMode.limitedRandom,
    AnswerMode answerMode = AnswerMode.enabledOnly,
    String id = 'a',
  }) =>
      TrainingAttempt(
        attemptId: id,
        sessionId: 's1',
        questionId: 'q-$id',
        correctInterval: correct,
        selectedInterval: uncertain ? null : selected,
        isUncertain: uncertain,
        replayCount: replays,
        responseDuration: Duration(milliseconds: ms),
        direction: direction,
        timbre: timbre,
        rootMode: rootMode,
        rootMidiNote: 60,
        answerMode: answerMode,
        focusPair: focusPair,
        createdAt: at ?? base,
      );

  group('StatsSnapshot 基础', () {
    test('空快照 isEmpty，intervalOf 返回空统计而非 null', () {
      final snapshot = StatsSnapshot.empty();
      expect(snapshot.isEmpty, isTrue);
      final stats = snapshot.intervalOf(IntervalId.tritone);
      expect(stats.interval, IntervalId.tritone);
      expect(stats.totalCount, 0);
      expect(snapshot.overallAccuracy(), 0);
    });

    test('withAttempt 累加音程统计与混淆矩阵', () {
      var snapshot = StatsSnapshot.empty();
      snapshot = snapshot.withAttempt(
        attempt(
          correct: IntervalId.majorThird,
          selected: IntervalId.minorThird,
          id: 'a1',
        ),
      );
      snapshot = snapshot.withAttempt(
        attempt(
          correct: IntervalId.majorThird,
          selected: IntervalId.majorThird,
          id: 'a2',
        ),
      );
      final stats = snapshot.intervalOf(IntervalId.majorThird);
      expect(stats.totalCount, 2);
      expect(stats.correctCount, 1);
      expect(
        snapshot.confusionMatrix
            .countOf(IntervalId.majorThird, IntervalId.minorThird),
        1,
      );
      expect(snapshot.totalQuestions, 2);
    });

    test('withAttempt 不共享可变混淆矩阵状态', () {
      final first = StatsSnapshot.empty().withAttempt(
        attempt(
          correct: IntervalId.majorThird,
          selected: IntervalId.minorThird,
          id: 'a1',
        ),
      );
      final second = first.withAttempt(
        attempt(
          correct: IntervalId.majorThird,
          selected: IntervalId.minorThird,
          id: 'a2',
        ),
      );
      // 旧快照不能被新快照的写入污染。
      expect(
        first.confusionMatrix
            .countOf(IntervalId.majorThird, IntervalId.minorThird),
        1,
      );
      expect(
        second.confusionMatrix
            .countOf(IntervalId.majorThird, IntervalId.minorThird),
        2,
      );
    });

    test('不确定不进混淆矩阵，但计入 totalCount', () {
      final snapshot = StatsSnapshot.empty().withAttempt(
        attempt(correct: IntervalId.tritone, uncertain: true, id: 'a1'),
      );
      final stats = snapshot.intervalOf(IntervalId.tritone);
      expect(stats.totalCount, 1);
      expect(stats.uncertainCount, 1);
      expect(stats.effectiveCount, 0);
      expect(snapshot.confusionMatrix.isEmpty, isTrue);
    });
  });

  group('rebuildFromAttempts 与增量一致（架构 §3.2 契约）', () {
    test('逐条累加 == 全量重算', () {
      final attempts = <TrainingAttempt>[
        attempt(
          correct: IntervalId.majorThird,
          selected: IntervalId.minorThird,
          id: 'a1',
        ),
        attempt(
          correct: IntervalId.minorThird,
          selected: IntervalId.minorThird,
          id: 'a2',
        ),
        attempt(correct: IntervalId.tritone, uncertain: true, id: 'a3'),
        attempt(
          correct: IntervalId.perfectFifth,
          selected: IntervalId.perfectFourth,
          id: 'a4',
          focusPair: 'P4|P5',
        ),
      ];
      var incremental = StatsSnapshot.empty();
      for (final a in attempts) {
        incremental = incremental.withAttempt(a);
      }
      final rebuilt = StatsSnapshot.rebuildFromAttempts(
        attempts,
        const <TrainingSession>[],
      );
      expect(rebuilt.totalQuestions, incremental.totalQuestions);
      expect(
        rebuilt.intervalOf(IntervalId.majorThird),
        incremental.intervalOf(IntervalId.majorThird),
      );
      expect(
        rebuilt.confusionMatrix.toJson(),
        incremental.confusionMatrix.toJson(),
      );
      expect(rebuilt.overallAccuracy(), incremental.overallAccuracy());
    });
  });

  group('DateKeys 与 DailySummary', () {
    test('日期键格式与解析往返', () {
      final key = DateKeys.of(DateTime(2026, 3, 9, 23, 30));
      expect(key, '2026-03-09');
      expect(DateKeys.isValid(key), isTrue);
      final parsed = DateKeys.parse(key)!;
      expect(parsed.isUtc, isTrue);
      expect(DateKeys.of(parsed.toUtc()), isNotNull);
    });

    test('addDays / differenceInDays', () {
      expect(DateKeys.addDays('2026-03-09', 2), '2026-03-11');
      expect(DateKeys.differenceInDays('2026-03-09', '2026-03-11'), 2);
      expect(DateKeys.compare('2026-03-09', '2026-03-11') < 0, isTrue);
    });

    test('DailySummary 累加与 JSON 往返', () {
      var day = DailySummary(dateKey: '2026-03-10');
      day = day.withAttempt(
        attempt(
          correct: IntervalId.majorThird,
          selected: IntervalId.majorThird,
          ms: 1500,
        ),
      );
      day = day.withAttempt(
        attempt(correct: IntervalId.tritone, uncertain: true, ms: 2000),
      );
      expect(day.questionCount, 2);
      expect(day.correctCount, 1);
      expect(day.uncertainCount, 1);
      // accuracy 含不确定；effectiveAccuracy 剔除不确定。
      expect(day.accuracy, 0.5);
      expect(day.effectiveAccuracy, 1.0);
      final back = DailySummary.fromJson(day.toJson());
      expect(back, day);
    });
  });

  group('StatsSnapshot JSON 往返', () {
    test('含全部子结构时往返等价', () {
      var snapshot = StatsSnapshot.empty();
      snapshot = snapshot.withAttempt(
        attempt(
          correct: IntervalId.majorSixth,
          selected: IntervalId.minorSixth,
          id: 'a1',
          focusPair: 'm6|M6',
          direction: PlaybackDirection.descending,
          timbre: Timbre.plucked,
          rootMode: RootMode.fullRandom,
          answerMode: AnswerMode.binary,
        ),
      );
      snapshot = snapshot.withSession(
        TrainingSession(
          sessionId: 's1',
          trainingMode: TrainingMode.daily,
          startedAt: base,
          finishedAt: base.add(const Duration(minutes: 5)),
          totalQuestions: 1,
          completedQuestions: 1,
          correctCount: 0,
          configSnapshot: TrainingConfig.defaults,
        ),
      );
      final json = snapshot.toJson();
      final back = StatsSnapshot.fromJson(json);
      expect(back.totalQuestions, snapshot.totalQuestions);
      expect(back.totalSessions, snapshot.totalSessions);
      expect(
        back.intervalOf(IntervalId.majorSixth),
        snapshot.intervalOf(IntervalId.majorSixth),
      );
      expect(back.confusionMatrix.toJson(), snapshot.confusionMatrix.toJson());
      expect(
        back.pairOf(IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth))
            .totalCount,
        1,
      );
      expect(back.lastTrainedAt, isNotNull);
    });

    test('recentDays 补全缺失日期', () {
      final snapshot = StatsSnapshot.empty().withAttempt(
        attempt(correct: IntervalId.majorThird, selected: IntervalId.majorThird),
      );
      final days = snapshot.recentDays(7, base.toLocal());
      expect(days.length, 7);
      // 最后一天是「今天」。
      expect(days.last.dateKey, DateKeys.of(base.toLocal()));
    });
  });

  group('PairStatistics 双侧统计', () {
    test('focusPair 的两侧分别累计，偏差可算', () {
      var snapshot = StatsSnapshot.empty();
      // m6 侧答对 2 次，M6 侧全错 2 次 → 侧偏差 = 1.0。
      for (var i = 0; i < 2; i++) {
        snapshot = snapshot.withAttempt(
          attempt(
            correct: IntervalId.minorSixth,
            selected: IntervalId.minorSixth,
            focusPair: 'm6|M6',
            id: 'low$i',
          ),
        );
        snapshot = snapshot.withAttempt(
          attempt(
            correct: IntervalId.majorSixth,
            selected: IntervalId.minorSixth,
            focusPair: 'm6|M6',
            id: 'high$i',
          ),
        );
      }
      final pair =
          snapshot.pairOf(IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth));
      expect(pair.totalCount, 4);
      expect(pair.correctCount, 2);
      // 两侧各练 2 次：正确率偏差 1.0（用户实际会分不清），但出题曝光均衡。
      expect(pair.sideBias, closeTo(1.0, 1e-9));
      expect(pair.isSideBalanced, isTrue);
    });

    test('曝光失衡时 isSideBalanced 为 false（3 次 low / 1 次 high）', () {
      var snapshot = StatsSnapshot.empty();
      for (var i = 0; i < 3; i++) {
        snapshot = snapshot.withAttempt(
          attempt(
            correct: IntervalId.minorSixth,
            selected: IntervalId.minorSixth,
            focusPair: 'm6|M6',
            id: 'low$i',
          ),
        );
      }
      snapshot = snapshot.withAttempt(
        attempt(
          correct: IntervalId.majorSixth,
          selected: IntervalId.majorSixth,
          focusPair: 'm6|M6',
          id: 'high',
        ),
      );
      final pair =
          snapshot.pairOf(IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth));
      expect(pair.isSideBalanced, isFalse);
    });
  });
}
