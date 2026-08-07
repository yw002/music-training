import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:interval_ear/features/free_training/presentation/free_training_cubit.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(TrainingConfig.defaults);
  });

  late MockSettingsRepository repo;
  late FreeTrainingCubit cubit;

  setUp(() {
    repo = MockSettingsRepository();
    cubit = FreeTrainingCubit(settingsRepo: repo);
  });

  tearDown(() => cubit.close());

  test('默认加载会从仓储恢复配置并清空校验', () async {
    when(() => repo.loadLastFreeConfig())
        .thenAnswer((_) async => TrainingConfig.defaults);
    await cubit.load();
    expect(cubit.state.config, TrainingConfig.defaults);
    expect(cubit.state.isValid, isTrue);
    verify(() => repo.loadLastFreeConfig()).called(1);
  });

  test('勾选与取消音程会更新配置', () {
    // 默认配置启用全部 13 个音程，故首次 toggle 为「取消」，再次为「勾选」。
    final IntervalId id = IntervalCatalog.trainableIds.first;
    cubit.toggleInterval(id);
    expect(cubit.state.config.enabledIntervals.contains(id), isFalse);
    cubit.toggleInterval(id);
    expect(cubit.state.config.enabledIntervals.contains(id), isTrue);
  });

  test('切换答题模式为二选一会强制恰好 2 个音程', () {
    cubit.setAnswerMode(AnswerMode.binary);
    expect(cubit.state.config.answerMode, AnswerMode.binary);
    expect(cubit.state.config.enabledIntervals.length, 2);
  });

  test('开始训练在音程不足 2 个时被校验拦截', () {
    cubit.emit(
      cubit.state.copyWith(
        config: TrainingConfig.defaults.copyWith(
          enabledIntervals: <IntervalId>{IntervalCatalog.trainableIds.first},
        ),
      ),
    );
    final bool ok = cubit.start();
    expect(ok, isFalse);
    expect(
      cubit.state.validation.errors.first.code,
      TrainingConfig.codeTooFewIntervals,
    );
  });

  test('开始训练在二选一非 2 个音程时被校验拦截', () {
    final Set<IntervalId> three =
        IntervalCatalog.trainableIds.take(3).toSet();
    cubit.emit(
      cubit.state.copyWith(
        config: TrainingConfig.defaults.copyWith(
          enabledIntervals: three,
          answerMode: AnswerMode.binary,
        ),
      ),
    );
    final bool ok = cubit.start();
    expect(ok, isFalse);
    expect(
      cubit.state.validation.errors.first.code,
      TrainingConfig.codeBinaryNeedsExactlyTwo,
    );
  });

  test('保存会调用仓储的 saveLastFreeConfig', () async {
    when(() => repo.saveLastFreeConfig(any()))
        .thenAnswer((_) async {});
    await cubit.save();
    verify(() => repo.saveLastFreeConfig(any())).called(1);
  });
}
