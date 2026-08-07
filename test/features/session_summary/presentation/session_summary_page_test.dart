import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_arguments.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_page.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';

import '../test_support.dart';

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
    );
  });

  late MockNavigatorObserver observer;

  /// 测试基座：注入 FakeAudioService（错题回放）+ reduced 动效作用域（防循环动画
  /// 致 pumpAndSettle 不收敛），路由未知名走 SizedBox 兜底。report 路由尚未接入，
  /// 由 onGenerateRoute 兜底，不崩。
  Future<void> pump(
    WidgetTester tester, {
    required TrainingSession session,
  }) async {
    observer = MockNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorObservers: <NavigatorObserver>[observer],
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SizedBox.shrink(),
        ),
        home: MotionScope(
          data: const MotionScopeData(
            level: MotionLevel.reduced,
            stage: MotionDegradeStage.none,
            userPreference: MotionPreference.system,
            systemReduceMotion: false,
          ),
          child: RepositoryProvider<AudioService>.value(
            value: FakeAudioService(),
            child: SessionSummaryPage(
              arguments: SessionSummaryArguments(session: session),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('展示正确率/用时/最长连击与错题清单', (tester) async {
    final mistakes = <TrainingAttempt>[
      makeAttempt(
        correct: IntervalId.perfectFifth,
        selected: IntervalId.perfectFourth,
      ),
      makeAttempt(correct: IntervalId.majorThird, uncertain: true),
    ];
    final session = makeSession(
      correctCount: 8,
      completedQuestions: 10,
      maxCombo: 5,
      mistakes: mistakes,
      elapsed: const Duration(seconds: 90),
    );

    await pump(tester, session: session);

    expect(find.text(AppStrings.summary.title), findsOneWidget);
    // 正确率 80%（M-25 数字滚动，reduced 档直达终态）。
    expect(find.text(AppStrings.unit.percent(80)), findsOneWidget);
    // 用时 1 分 30 秒。
    expect(find.text('1 分钟 30 秒'), findsOneWidget);
    // 最长连击 5 次。
    expect(find.text(AppStrings.unit.times('5')), findsOneWidget);
    // 错题清单标题与逐条复用对比播放按钮（ABCompareButton）。
    expect(find.textContaining('错题 1'), findsOneWidget);
    expect(find.byIcon(Icons.compare_arrows_rounded), findsNWidgets(2));
    // 操作按钮。
    expect(find.text(AppStrings.summary.playAgain), findsOneWidget);
    expect(find.text(AppStrings.summary.viewReport), findsOneWidget);
  });

  testWidgets('无错题时展示空态且不渲染对比按钮', (tester) async {
    final session = makeSession(
      correctCount: 10,
      completedQuestions: 10,
      maxCombo: 7,
      mistakes: const <TrainingAttempt>[],
      elapsed: const Duration(seconds: 45),
    );

    await pump(tester, session: session);

    expect(find.text(AppStrings.common.empty), findsWidgets);
    expect(find.byIcon(Icons.compare_arrows_rounded), findsNothing);
  });

  testWidgets('点击查看报告会跳转到报告路由', (tester) async {
    final session = makeSession(mistakes: const <TrainingAttempt>[]);

    await pump(tester, session: session);

    await tester.ensureVisible(find.text(AppStrings.summary.viewReport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.summary.viewReport));
    await tester.pumpAndSettle();

    // 初始 home 入栈 1 次 + 查看报告 pushNamed 1 次，共 2 次 didPush。
    verify(() => observer.didPush(any(), any())).called(2);
  });

  testWidgets('点击再来一组会用相同配置重开训练路由', (tester) async {
    final session = makeSession(mistakes: const <TrainingAttempt>[]);

    await pump(tester, session: session);

    await tester.ensureVisible(find.text(AppStrings.summary.playAgain));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.summary.playAgain));
    await tester.pumpAndSettle();

    verify(
      () => observer.didReplace(
        newRoute: any(named: 'newRoute'),
        oldRoute: any(named: 'oldRoute'),
      ),
    ).called(1);
  });
}
