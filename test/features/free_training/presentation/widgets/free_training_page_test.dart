import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/free_training/presentation/free_training_cubit.dart';
import 'package:interval_ear/features/free_training/presentation/free_training_page.dart';
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
    when(() => repo.loadLastFreeConfig())
        .thenAnswer((_) async => TrainingConfig.defaults);
    when(() => repo.saveLastFreeConfig(any())).thenAnswer((_) async {});
  });

  tearDown(() => cubit.close());

  // 基座：FakeAudioService 注入 + 虚拟动效作用域（reduced 防止循环动画致
  // pumpAndSettle 不收敛），由外部 BlocProvider 提供 Cubit 以便断言状态。
  //
  // 放大视口到 2400px：自由训练页用 ListView，子项经 SliverChildListDelegate
  // 懒构建，普通测试视口只渲染首屏分区；放大后所有分区进入视口，便于断言
  // 「全部配置分区渲染」（架构 §5 T19 验收 ①），无需真实滚动。
  //
  // onGenerateRoute 兜底：页面「开始训练」会 pushNamed 到训练页，单测环境无该
  // 路由，用占位页接住，避免导航抛错干扰 save 的断言。
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: (RouteSettings _) => MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
        ),
        home: MotionScope(
          data: const MotionScopeData(
            level: MotionLevel.reduced,
            stage: MotionDegradeStage.none,
            userPreference: MotionPreference.system,
            systemReduceMotion: false,
          ),
          child: MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<SettingsRepository>.value(value: repo),
              RepositoryProvider<AudioService>.value(value: FakeAudioService()),
            ],
            child: BlocProvider<FreeTrainingCubit>.value(
              value: cubit,
              child: const FreeTrainingPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('渲染标题与全部配置分区', (tester) async {
    await pump(tester);
    expect(find.text(AppStrings.freeTraining.title), findsOneWidget);
    expect(find.text(AppStrings.freeTraining.intervalSection), findsOneWidget);
    expect(find.text(AppStrings.freeTraining.directionSection), findsOneWidget);
    expect(find.text(AppStrings.freeTraining.rootSection), findsOneWidget);
    expect(find.text(AppStrings.freeTraining.timbreSection), findsOneWidget);
    expect(
      find.text(AppStrings.freeTraining.questionCountSection),
      findsOneWidget,
    );
    // 「二选一」既是分区标题也是答题模式选项文案，至少出现一次即可。
    expect(find.text(AppStrings.freeTraining.answerModeBinary), findsWidgets);
    expect(find.text(AppStrings.freeTraining.startTraining), findsOneWidget);
  });

  testWidgets('点击音程 chip 会切换选中状态', (tester) async {
    await pump(tester);
    final IntervalId id = IntervalCatalog.trainableIds.elementAt(5);
    final String label = IntervalCatalog.nameOf(id);
    final Finder chip = find.widgetWithText(FilterChip, label);
    expect(chip, findsOneWidget);
    // 默认启用全部 13 音程，该 chip 初始即为选中。
    expect(tester.widget<FilterChip>(chip).selected, isTrue);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(chip).selected, isFalse);
  });

  testWidgets('音程不足 2 个时点击开始训练会在 UI 提示校验错误', (tester) async {
    // 恢复一份非法（仅 1 音程）的上次配置；load() 乐观清空校验，故需经 start()
    // 触发 TrainingConfig.validate() 才显示错误（架构 §5 T19 验收 ②）。
    when(() => repo.loadLastFreeConfig()).thenAnswer(
      (_) async => TrainingConfig.defaults.copyWith(
        enabledIntervals: <IntervalId>{IntervalCatalog.trainableIds.first},
      ),
    );
    await pump(tester);
    await tester.tap(find.text(AppStrings.freeTraining.startTraining));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.freeTraining.needAtLeastTwoIntervals),
      findsOneWidget,
    );
    // 校验失败不应持久化。
    verifyNever(() => repo.saveLastFreeConfig(any()));
  });

  testWidgets('点击开始训练会持久化配置', (tester) async {
    await pump(tester);
    await tester.tap(find.text(AppStrings.freeTraining.startTraining));
    await tester.pumpAndSettle();
    verify(() => repo.saveLastFreeConfig(any())).called(1);
  });
}
