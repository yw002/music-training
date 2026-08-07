import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/stats/accuracy_bucket.dart';
import 'package:interval_ear/features/training/domain/stats/confusion_matrix.dart';
import 'package:interval_ear/features/training/domain/stats/daily_summary.dart';
import 'package:interval_ear/features/training/domain/stats/dimension_statistics.dart';
import 'package:interval_ear/features/training/domain/stats/interval_statistics.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 一个非空、确定、覆盖各维度的 [StatsSnapshot]，供报告页与 Cubit 测试复用。
///
/// 不使用随机或 `DateTime.now()`，保证测试可复现。
StatsSnapshot sampleSnapshot() {
  final Map<IntervalId, IntervalStatistics> intervals =
      <IntervalId, IntervalStatistics>{
    IntervalId.perfectUnison: const IntervalStatistics(
      interval: IntervalId.perfectUnison,
      correctCount: 95,
      totalCount: 100,
    ),
    IntervalId.minorSecond: const IntervalStatistics(
      interval: IntervalId.minorSecond,
      correctCount: 60,
      totalCount: 100,
    ),
    IntervalId.majorSecond: const IntervalStatistics(
      interval: IntervalId.majorSecond,
      correctCount: 70,
      totalCount: 100,
    ),
    IntervalId.tritone: const IntervalStatistics(
      interval: IntervalId.tritone,
      correctCount: 40,
      totalCount: 100,
    ),
    IntervalId.perfectOctave: const IntervalStatistics(
      interval: IntervalId.perfectOctave,
      correctCount: 92,
      totalCount: 100,
    ),
  };

  final ConfusionMatrix matrix = ConfusionMatrix.empty();
  matrix.increment(IntervalId.perfectUnison, IntervalId.perfectUnison, by: 95);
  matrix.increment(IntervalId.minorSecond, IntervalId.minorSecond, by: 60);
  matrix.increment(IntervalId.minorSecond, IntervalId.majorSecond, by: 25);
  matrix.increment(IntervalId.minorSecond, IntervalId.minorThird, by: 15);
  matrix.increment(IntervalId.majorSecond, IntervalId.majorSecond, by: 70);
  matrix.increment(IntervalId.majorSecond, IntervalId.minorSecond, by: 20);
  matrix.increment(IntervalId.tritone, IntervalId.tritone, by: 40);
  matrix.increment(IntervalId.tritone, IntervalId.perfectFourth, by: 30);
  matrix.increment(IntervalId.perfectOctave, IntervalId.perfectOctave, by: 92);

  final DimensionStatistics dimensions = DimensionStatistics(
    byDirection: <PlaybackDirection, AccuracyBucket>{
      PlaybackDirection.ascending:
          const AccuracyBucket(total: 200, correct: 160),
      PlaybackDirection.descending:
          const AccuracyBucket(total: 200, correct: 120),
      PlaybackDirection.harmonic:
          const AccuracyBucket(total: 100, correct: 70),
    },
    byTimbre: <Timbre, AccuracyBucket>{
      Timbre.keyboard: const AccuracyBucket(total: 300, correct: 240),
      Timbre.plucked: const AccuracyBucket(total: 200, correct: 110),
    },
    byRootMode: <RootMode, AccuracyBucket>{
      RootMode.fixed: const AccuracyBucket(total: 250, correct: 200),
      RootMode.limitedRandom: const AccuracyBucket(total: 150, correct: 100),
      RootMode.fullRandom: const AccuracyBucket(total: 100, correct: 50),
    },
  );

  final Map<String, DailySummary> daily = <String, DailySummary>{
    '2025-06-10': const DailySummary(
      dateKey: '2025-06-10',
      questionCount: 20,
      correctCount: 16,
    ),
    '2025-06-11': const DailySummary(
      dateKey: '2025-06-11',
      questionCount: 25,
      correctCount: 20,
    ),
    '2025-06-12': const DailySummary(
      dateKey: '2025-06-12',
      questionCount: 18,
      correctCount: 12,
    ),
    '2025-06-13': const DailySummary(
      dateKey: '2025-06-13',
      questionCount: 30,
      correctCount: 24,
    ),
    '2025-06-14': const DailySummary(
      dateKey: '2025-06-14',
      questionCount: 22,
      correctCount: 19,
    ),
    '2025-06-15': const DailySummary(
      dateKey: '2025-06-15',
      questionCount: 28,
      correctCount: 22,
    ),
  };

  return StatsSnapshot(
    intervals: intervals,
    confusionMatrix: matrix,
    dimensions: dimensions,
    daily: daily,
    totalSessions: 30,
    totalQuestions: 600,
    lastTrainedAt: DateTime(2025, 6, 15, 21, 0),
  );
}
