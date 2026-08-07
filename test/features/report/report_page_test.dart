import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/report/presentation/report_page.dart';
import 'package:interval_ear/features/report/presentation/widgets/confusion_matrix_view.dart';
import 'package:interval_ear/features/report/presentation/widgets/daily_heatmap.dart';
import 'package:interval_ear/features/report/presentation/widgets/dimension_breakdown.dart';
import 'package:interval_ear/features/report/presentation/widgets/empty_report_state.dart';
import 'package:interval_ear/features/report/presentation/widgets/interval_accuracy_chart.dart';
import 'package:interval_ear/features/report/presentation/widgets/overview_cards.dart';
import 'package:interval_ear/features/report/presentation/widgets/trend_line_chart.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';
import 'package:mocktail/mocktail.dart';

import 'test_data.dart';

class MockTrainingRepository extends Mock implements TrainingRepository {}

Widget _boot(TrainingRepository repo) => MaterialApp(
      theme: AppTheme.light,
      home: MotionScope(
        data: MotionScopeData(
          // reduced：让分区交错入场直接落到终态（opacity=1、onstage），
          // 避免依赖 Future.delayed 的 stagger 在 pumpAndSettle 下不收敛；
          // 同时验证六个分区都能正常渲染（非空态）。
          level: MotionLevel.reduced,
          stage: MotionDegradeStage.none,
          userPreference: MotionPreference.system,
          systemReduceMotion: false,
        ),
        child: RepositoryProvider<TrainingRepository>(
          create: (_) => repo,
          child: const ReportPage(),
        ),
      ),
    );

void main() {
  late MockTrainingRepository repo;

  setUp(() => repo = MockTrainingRepository());

  testWidgets('非空数据渲染全部六个图表分区', (tester) async {
    // 报告页是纵向 ListView，下方分区（混淆矩阵 / 维度 / 热力图）在默认
    // 800x600 视口下位于折下方、不会实例化。拉高视口让六个分区同屏可见，
    // 这样 find.byType 才能命中全部图表组件。
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    when(() => repo.loadStats()).thenAnswer((_) async => sampleSnapshot());
    await tester.pumpWidget(_boot(repo));
    await tester.pumpAndSettle();
    expect(find.byType(OverviewCards), findsOneWidget);
    expect(find.byType(IntervalAccuracyChart), findsOneWidget);
    expect(find.byType(ConfusionMatrixView), findsOneWidget);
    expect(find.byType(TrendLineChart), findsOneWidget);
    expect(find.byType(DimensionBreakdown), findsOneWidget);
    expect(find.byType(DailyHeatmap), findsOneWidget);
  });

  testWidgets('空数据展示友好空态（不崩）', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    when(() => repo.loadStats()).thenAnswer((_) async => StatsSnapshot.empty());
    await tester.pumpWidget(_boot(repo));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyReportState), findsOneWidget);
    expect(find.text(AppStrings.report.notEnoughData), findsWidgets);
  });
}
