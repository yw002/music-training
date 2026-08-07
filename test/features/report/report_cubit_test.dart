import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/features/report/presentation/report_cubit.dart';
import 'package:interval_ear/features/report/presentation/report_state.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';
import 'package:mocktail/mocktail.dart';

import 'test_data.dart';

class MockTrainingRepository extends Mock implements TrainingRepository {}

void main() {
  late MockTrainingRepository repo;
  final DateTime fixedNow = DateTime(2025, 6, 15, 12, 0);

  setUp(() => repo = MockTrainingRepository());

  test('load 成功 -> ReportReady（非空不崩）', () async {
    when(() => repo.loadStats()).thenAnswer((_) async => sampleSnapshot());
    final ReportCubit cubit = ReportCubit(
      trainingRepo: repo,
      clock: () => fixedNow,
    );
    expect(cubit.state, isA<ReportInitial>());
    await cubit.load();
    expect(cubit.state, isA<ReportReady>());
    final ReportReady ready = cubit.state as ReportReady;
    expect(ready.snapshot.isEmpty, isFalse);
    expect(ready.snapshot.totalQuestions, greaterThan(0));
    expect(cubit.now, fixedNow);
    await cubit.close();
  });

  test('load 空快照 -> ReportReady 不崩', () async {
    when(() => repo.loadStats()).thenAnswer((_) async => StatsSnapshot.empty());
    final ReportCubit cubit = ReportCubit(
      trainingRepo: repo,
      clock: () => fixedNow,
    );
    await cubit.load();
    expect(cubit.state, isA<ReportReady>());
    expect((cubit.state as ReportReady).snapshot.isEmpty, isTrue);
    await cubit.close();
  });

  test('load 仓储抛异常 -> ReportError（不向上传播）', () async {
    when(() => repo.loadStats())
        .thenAnswer((_) async => throw Exception('boom'));
    final ReportCubit cubit = ReportCubit(
      trainingRepo: repo,
      clock: () => fixedNow,
    );
    await cubit.load();
    expect(cubit.state, isA<ReportError>());
    expect((cubit.state as ReportError).message, isNotEmpty);
    await cubit.close();
  });
}
