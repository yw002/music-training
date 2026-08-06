import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:interval_ear/features/home/presentation/home_cubit.dart';
import 'package:interval_ear/features/home/presentation/home_state.dart';
import 'package:interval_ear/features/training/domain/models/course_preset.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/stats/interval_statistics.dart';
import 'package:interval_ear/features/training/domain/repositories/recovery_report.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

class MockTrainingRepository extends Mock implements TrainingRepository {}

void main() {
  group('HomeCubit', () {
    late MockTrainingRepository repo;
    late HomeCubit cubit;

    setUp(() {
      repo = MockTrainingRepository();
      cubit = HomeCubit(trainingRepo: repo);
    });

    tearDown(() => cubit.close());

    test('empty snapshot degenerates to chapter one and marks all weak',
        () async {
      when(() => repo.loadStats()).thenAnswer((_) async => StatsSnapshot.empty());
      when(() => repo.takeRecoveryReport()).thenAnswer((_) async => null);
      await cubit.load();

      expect(cubit.state, isA<HomeLoaded>());
      final HomeLoaded loaded = cubit.state as HomeLoaded;
      expect(loaded.snapshot.isEmpty, isTrue);
      expect(
        loaded.todayConfig.enabledIntervals.length,
        CourseChapters.one.intervals.length,
      );
      expect(loaded.weakIntervals.length, IntervalCatalog.trainableIds.length);
      expect(loaded.streakDays, 0);
    });

    test('non-empty snapshot uses full defaults and separates weak from strong',
        () async {
      final StatsSnapshot snapshot = StatsSnapshot(
        intervals: <IntervalId, IntervalStatistics>{
          IntervalId.perfectUnison: IntervalStatistics(
            interval: IntervalId.perfectUnison,
            correctCount: 100,
            totalCount: 100,
          ),
          IntervalId.minorSecond: const IntervalStatistics(
            interval: IntervalId.minorSecond,
          ),
        },
      );
      when(() => repo.loadStats()).thenAnswer((_) async => snapshot);
      when(() => repo.takeRecoveryReport()).thenAnswer((_) async => null);
      await cubit.load();

      final HomeLoaded loaded = cubit.state as HomeLoaded;
      expect(loaded.snapshot.isEmpty, isFalse);
      expect(
        loaded.todayConfig.enabledIntervals.length,
        IntervalCatalog.trainableIds.length,
      );
      expect(loaded.weakIntervals.contains(IntervalId.perfectUnison), isFalse);
      expect(loaded.weakIntervals.contains(IntervalId.minorSecond), isTrue);
    });

    test('surfaces recovery dropped lines exactly once', () async {
      when(() => repo.loadStats()).thenAnswer((_) async => StatsSnapshot.empty());
      when(() => repo.takeRecoveryReport()).thenAnswer(
        (_) async => const RecoveryReport(skippedAttemptLines: 3),
      );
      await cubit.load();

      final HomeLoaded loaded = cubit.state as HomeLoaded;
      expect(loaded.recoveryDroppedLines, 3);
    });
  });
}
