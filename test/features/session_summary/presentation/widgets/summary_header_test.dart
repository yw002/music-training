import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_cubit.dart';
import 'package:interval_ear/features/session_summary/presentation/widgets/summary_header.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';

import '../../test_support.dart';

Future<void> pumpHeader(WidgetTester tester, TrainingSession session) async {
  final cubit = SessionSummaryCubit(session: session);
  final summary = cubit.state.summary;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MotionScope(
        data: const MotionScopeData(
          level: MotionLevel.reduced,
          stage: MotionDegradeStage.none,
          userPreference: MotionPreference.system,
          systemReduceMotion: false,
        ),
        child: Scaffold(
          body: Center(child: SummaryHeader(summary: summary)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  cubit.close();
}

void main() {
  testWidgets('展示正确率 / 用时 / 最长连击', (tester) async {
    final session = makeSession(
      correctCount: 8,
      completedQuestions: 10,
      maxCombo: 5,
      mistakes: const <TrainingAttempt>[],
      elapsed: const Duration(seconds: 90),
    );

    await pumpHeader(tester, session);

    // 正确率 80%（M-25 数字滚动，reduced 档直达终态）。
    expect(find.text(AppStrings.unit.percent(80)), findsOneWidget);
    // 用时 1 分 30 秒。
    expect(find.text('1 分钟 30 秒'), findsOneWidget);
    // 最长连击 5 次。
    expect(find.text(AppStrings.unit.times('5')), findsOneWidget);
  });

  testWidgets('未结算时用时显示暂无数据', (tester) async {
    final session = makeSession(
      correctCount: 0,
      completedQuestions: 0,
      mistakes: const <TrainingAttempt>[],
    );

    await pumpHeader(tester, session);

    expect(find.text(AppStrings.common.empty), findsWidgets);
    expect(find.text(AppStrings.unit.percent(0)), findsOneWidget);
  });
}
