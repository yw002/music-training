import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/app/router/transitions/container_transform_route.dart';
import 'package:interval_ear/app/router/transitions/fade_through_route.dart';
import 'package:interval_ear/app/router/transitions/shared_axis_route.dart';
import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// T03 验收项：3 个转场各写一个 widget test，覆盖 full / reduced / off 三档时长。
void main() {
  const AppMotionTokens tokens = AppMotionTokens.standard();

  /// 搭一个可以 push 的最小宿主，返回 navigator key 以便直接下发路由。
  Widget host(GlobalKey<NavigatorState> key) => MaterialApp(
        theme: AppTheme.dark,
        navigatorKey: key,
        home: const Scaffold(body: Center(child: Text('首页'))),
      );

  Widget page(String label) => Scaffold(body: Center(child: Text(label)));

  group('FadeThroughPageRoute（M-01/M-02 降级 + 桌面端兜底）', () {
    test('时长按档位：full/reduced = reducedFade，off = 0', () {
      final Duration reduced = tokens.transition.reducedFade.duration;
      expect(FadeThroughPageRoute.durationFor(MotionLevel.full), reduced);
      expect(FadeThroughPageRoute.durationFor(MotionLevel.reduced), reduced);
      expect(FadeThroughPageRoute.durationFor(MotionLevel.off), Duration.zero);
      expect(reduced, const Duration(milliseconds: 150));
    });

    testWidgets('full 档：150ms 内完成淡入且新页可见', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      unawaitedPush(
        key,
        FadeThroughPageRoute<void>(
          builder: (_) => page('淡入页'),
          motionLevel: MotionLevel.full,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.text('淡入页'), findsOneWidget);

      // 动画中途透明度应处于 (0, 1) 开区间。
      final double mid = opacityOf(tester, '淡入页');
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(opacityOf(tester, '淡入页'), 1.0);
      expect(find.text('首页'), findsNothing);
    });

    testWidgets('off 档：0ms，一帧到位', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      final FadeThroughPageRoute<void> route = FadeThroughPageRoute<void>(
        builder: (_) => page('瞬时页'),
        motionLevel: MotionLevel.off,
      );
      expect(route.transitionDuration, Duration.zero);

      unawaitedPush(key, route);
      await tester.pump();
      await tester.pump();
      expect(find.text('瞬时页'), findsOneWidget);
      expect(opacityOf(tester, '瞬时页'), 1.0);
    });

    testWidgets('pop 后返回上一页', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));
      unawaitedPush(
        key,
        FadeThroughPageRoute<void>(
          builder: (_) => page('淡入页'),
          motionLevel: MotionLevel.full,
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('淡入页'), findsNothing);
    });
  });

  group('SharedAxisPageRoute（M-02 / M-03）', () {
    test('specFor：x/y → standardPush，z → trainingToReport 的 enter', () {
      expect(SharedAxisPageRoute.specFor(SharedAxis.x), tokens.transition.standardPush);
      expect(SharedAxisPageRoute.specFor(SharedAxis.y), tokens.transition.standardPush);
      expect(
        SharedAxisPageRoute.specFor(SharedAxis.z),
        tokens.transition.trainingToReport,
      );
    });

    test('durationFor：reduced 走淡入淡出时长，off 归零', () {
      for (final SharedAxis axis in SharedAxis.values) {
        expect(
          SharedAxisPageRoute.durationFor(axis, MotionLevel.full),
          SharedAxisPageRoute.specFor(axis).duration,
        );
        expect(
          SharedAxisPageRoute.durationFor(axis, MotionLevel.reduced),
          tokens.transition.reducedFade.duration,
        );
        expect(
          SharedAxisPageRoute.durationFor(axis, MotionLevel.off),
          Duration.zero,
        );
      }
    });

    testWidgets('X 轴 full 档：动画中存在水平位移，结束后归零', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      unawaitedPush(
        key,
        SharedAxisXPageRoute<void>(
          builder: (_) => page('横移页'),
          motionLevel: MotionLevel.full,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final Offset moving = tester.getTopLeft(find.text('横移页'));
      await tester.pumpAndSettle();
      final Offset settled = tester.getTopLeft(find.text('横移页'));
      expect(
        moving.dx,
        isNot(closeTo(settled.dx, 0.5)),
        reason: 'full 档 X 轴转场必须有可见水平位移',
      );
      expect(find.text('横移页'), findsOneWidget);
    });

    testWidgets('reduced 档：只淡入，无位移', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      unawaitedPush(
        key,
        SharedAxisXPageRoute<void>(
          builder: (_) => page('精简页'),
          motionLevel: MotionLevel.reduced,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final Offset moving = tester.getTopLeft(find.text('精简页'));
      await tester.pumpAndSettle();
      final Offset settled = tester.getTopLeft(find.text('精简页'));
      expect(moving.dx, closeTo(settled.dx, 0.01), reason: 'reduced 档禁止位移');
      expect(moving.dy, closeTo(settled.dy, 0.01));
    });

    testWidgets('Z 轴 full 档：结束后新页完全可见', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      unawaitedPush(
        key,
        SharedAxisZPageRoute<void>(
          builder: (_) => page('汇总页'),
          motionLevel: MotionLevel.full,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.text('汇总页'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(opacityOf(tester, '汇总页'), 1.0);
    });

    test('SharedAxis 位移量固定 30dp，z 轴无位移', () {
      expect(SharedAxis.x.travel, 30.0);
      expect(SharedAxis.y.travel, 30.0);
      expect(SharedAxis.z.travel, 0.0);
    });
  });

  group('ContainerTransformPageRoute（M-01 首页 → 训练）', () {
    test('spec 取自 transition.homeToTraining：420ms / 340ms', () {
      expect(ContainerTransformPageRoute.spec, tokens.transition.homeToTraining);
      expect(
        ContainerTransformPageRoute.enterDurationFor(MotionLevel.full),
        const Duration(milliseconds: 420),
      );
      expect(
        ContainerTransformPageRoute.exitDurationFor(MotionLevel.full),
        const Duration(milliseconds: 340),
      );
    });

    test('非 full 档收敛到淡入淡出 / 零时长', () {
      final Duration reduced = tokens.transition.reducedFade.duration;
      expect(
        ContainerTransformPageRoute.enterDurationFor(MotionLevel.reduced),
        reduced,
      );
      expect(
        ContainerTransformPageRoute.exitDurationFor(MotionLevel.reduced),
        reduced,
      );
      expect(
        ContainerTransformPageRoute.enterDurationFor(MotionLevel.off),
        Duration.zero,
      );
      expect(
        ContainerTransformPageRoute.exitDurationFor(MotionLevel.off),
        Duration.zero,
      );
    });

    testWidgets('full 档：从 0.92 缩放到 1.0，结束后尺寸归位', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      unawaitedPush(
        key,
        ContainerTransformPageRoute<void>(
          builder: (_) => page('训练页'),
          motionLevel: MotionLevel.full,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Transform 不改变布局尺寸，必须用 getRect（走 localToGlobal）才能看到缩放。
      final Finder target = find.ancestor(
        of: find.text('训练页'),
        matching: find.byType(Scaffold),
      );
      final Rect moving = tester.getRect(target);
      await tester.pumpAndSettle();
      final Rect settled = tester.getRect(target);

      expect(moving.width, lessThan(settled.width));
      expect(moving.width / settled.width, greaterThanOrEqualTo(0.9));
      expect(find.text('训练页'), findsOneWidget);
      expect(opacityOf(tester, '训练页'), 1.0);
    });

    testWidgets('reduced 档：无缩放，仅淡入', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      unawaitedPush(
        key,
        ContainerTransformPageRoute<void>(
          builder: (_) => page('训练页'),
          motionLevel: MotionLevel.reduced,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final Finder target = find.ancestor(
        of: find.text('训练页'),
        matching: find.byType(Scaffold),
      );
      final Rect moving = tester.getRect(target);
      await tester.pumpAndSettle();
      expect(tester.getRect(target), moving, reason: 'reduced 档禁止缩放');
    });

    testWidgets('off 档：一帧到位', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      final ContainerTransformPageRoute<void> route =
          ContainerTransformPageRoute<void>(
        builder: (_) => page('训练页'),
        motionLevel: MotionLevel.off,
      );
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);

      unawaitedPush(key, route);
      await tester.pump();
      await tester.pump();
      expect(opacityOf(tester, '训练页'), 1.0);
    });
  });
}

/// 下发一个路由但不等待返回值（widget test 里不需要 await push 的 Future）。
void unawaitedPush(GlobalKey<NavigatorState> key, Route<void> route) {
  key.currentState!.push<void>(route);
}

/// 读取某段文字所在子树上所有 [FadeTransition] 的累计透明度。
double opacityOf(WidgetTester tester, String text) {
  final Iterable<FadeTransition> transitions = tester.widgetList<FadeTransition>(
    find.ancestor(
      of: find.text(text),
      matching: find.byType(FadeTransition),
    ),
  );
  double value = 1.0;
  for (final FadeTransition t in transitions) {
    value *= t.opacity.value;
  }
  return value;
}
