import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/home/presentation/home_cubit.dart';
import 'package:interval_ear/features/home/presentation/home_page.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

class MockTrainingRepository extends Mock implements TrainingRepository {}

void main() {
  late MockTrainingRepository repo;
  late HomeCubit cubit;

  setUp(() {
    repo = MockTrainingRepository();
    cubit = HomeCubit(trainingRepo: repo);
  });

  tearDown(() => cubit.close());

  // 用 reduced 档：环境背景/呼吸动效不进入无限循环，pumpAndSettle 可稳定收敛。
  Future<void> pump(WidgetTester tester) async {
    when(() => repo.loadStats()).thenAnswer((_) async => StatsSnapshot.empty());
    when(() => repo.takeRecoveryReport()).thenAnswer((_) async => null);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
        ),
        home: MotionScope(
          data: const MotionScopeData(
            level: MotionLevel.reduced,
            stage: MotionDegradeStage.none,
            userPreference: MotionPreference.system,
            systemReduceMotion: false,
          ),
          child: BlocProvider<HomeCubit>.value(
            value: cubit,
            child: const HomePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders today card after load', (tester) async {
    await pump(tester);
    expect(find.text(AppStrings.home.todayCardTitle), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, AppStrings.home.startTodayTraining),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides weak section when snapshot is empty', (tester) async {
    await pump(tester);
    expect(find.text(AppStrings.home.weakSectionTitle), findsNothing);
  });

  testWidgets('start button navigates without crashing', (tester) async {
    await pump(tester);
    await tester.tap(
      find.widgetWithText(ElevatedButton, AppStrings.home.startTodayTraining),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick entry tiles are present', (tester) async {
    await pump(tester);
    expect(find.text(AppStrings.home.freeTrainingEntry), findsOneWidget);
    expect(find.text(AppStrings.home.binaryTrainingEntry), findsOneWidget);
    expect(find.text(AppStrings.home.reportEntry), findsOneWidget);
    expect(find.text(AppStrings.settings.title), findsOneWidget);
    expect(find.text(AppStrings.about.title), findsOneWidget);
  });
}
