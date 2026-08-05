import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/app/router/app_router.dart';
import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/app/router/transitions/container_transform_route.dart';
import 'package:interval_ear/app/router/transitions/fade_through_route.dart';
import 'package:interval_ear/app/router/transitions/shared_axis_route.dart';
import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_level.dart';

/// T01 验收项：路由骨架可导航、未注册路由有可用兜底页。
void main() {
  Widget probe(String label) => Scaffold(body: Center(child: Text(label)));

  group('RouteNames 注册表', () {
    test('全部路由名以 / 开头且互不重复', () {
      expect(RouteNames.all, isNotEmpty);
      expect(RouteNames.all.toSet().length, RouteNames.all.length);
      for (final String name in RouteNames.all) {
        expect(name.startsWith('/'), isTrue, reason: name);
      }
    });

    test('首页为 /，isKnown 只认注册过的名字', () {
      expect(RouteNames.home, '/');
      expect(RouteNames.all, contains(RouteNames.home));
      for (final String name in RouteNames.all) {
        expect(RouteNames.isKnown(name), isTrue, reason: name);
      }
      expect(RouteNames.isKnown('/definitely-not-registered'), isFalse);
      expect(RouteNames.isKnown(''), isFalse);
    });
  });

  group('AppRoutePages 注册与兜底', () {
    testWidgets('未注册路由 resolve 出占位页', (WidgetTester tester) async {
      final BuildContext context = await captureContext(tester);
      const AppRoutePages pages = AppRoutePages.empty();
      final Widget widget = pages.resolve('/nope')(context, null);
      expect(widget, isA<RoutePlaceholderPage>());
      expect((widget as RoutePlaceholderPage).routeName, '/nope');
    });

    testWidgets('withPages 合并新页面且不影响原对象', (WidgetTester tester) async {
      final BuildContext context = await captureContext(tester);
      const AppRoutePages base = AppRoutePages.empty();
      final AppRoutePages extended = base.withPages(<String, AppPageBuilder>{
        RouteNames.settings: (BuildContext context, Object? arguments) => probe('设置'),
      });
      expect(base.builders, isEmpty);
      expect(extended.builders.containsKey(RouteNames.settings), isTrue);
      expect(
        extended.resolve(RouteNames.settings)(context, null),
        isA<Scaffold>(),
      );
      expect(
        extended.resolve('/unknown')(context, null),
        isA<RoutePlaceholderPage>(),
      );
    });
  });

  group('AppRouter.buildRoute 分支（架构 §1.6 路由表）', () {
    const RouteSettings settings = RouteSettings(name: '/x');
    Widget builder(BuildContext context) => probe('页');

    test('full 档：训练页与二选一训练页走 ContainerTransform（M-01）', () {
      for (final String name in <String>[
        RouteNames.training,
        RouteNames.binaryTraining,
      ]) {
        expect(
          AppRouter.buildRoute(name, builder, settings, MotionLevel.full),
          isA<ContainerTransformPageRoute<void>>(),
          reason: name,
        );
      }
    });

    test('full 档：总结页走 Shared Axis Z（M-02）', () {
      final Route<dynamic> route = AppRouter.buildRoute(
        RouteNames.sessionSummary,
        builder,
        settings,
        MotionLevel.full,
      );
      expect(route, isA<SharedAxisZPageRoute<void>>());
      expect((route as SharedAxisPageRoute<void>).axis, SharedAxis.z);
    });

    test('full 档：首页走 FadeThrough', () {
      expect(
        AppRouter.buildRoute(RouteNames.home, builder, settings, MotionLevel.full),
        isA<FadeThroughPageRoute<void>>(),
      );
    });

    test('full 档：其余页面走 Shared Axis X（M-03）', () {
      for (final String name in <String>[
        RouteNames.settings,
        RouteNames.report,
        RouteNames.about,
        RouteNames.weakPairs,
        RouteNames.freeTraining,
      ]) {
        final Route<dynamic> route =
            AppRouter.buildRoute(name, builder, settings, MotionLevel.full);
        expect(route, isA<SharedAxisXPageRoute<void>>(), reason: name);
        expect((route as SharedAxisPageRoute<void>).axis, SharedAxis.x);
      }
    });

    test('非 full 档：所有路由统一降级为 FadeThrough（PRD §3.10）', () {
      for (final MotionLevel level in <MotionLevel>[
        MotionLevel.reduced,
        MotionLevel.off,
      ]) {
        for (final String name in RouteNames.all) {
          expect(
            AppRouter.buildRoute(name, builder, settings, level),
            isA<FadeThroughPageRoute<void>>(),
            reason: '$name @ $level',
          );
        }
      }
    });

    test('off 档转场时长为 0', () {
      final Route<dynamic> route = AppRouter.buildRoute(
        RouteNames.training,
        builder,
        settings,
        MotionLevel.off,
      );
      expect((route as PageRoute<dynamic>).transitionDuration, Duration.zero);
    });

    test('settings 原样透传，便于 Navigator 的 popUntil / 名称匹配', () {
      const RouteSettings custom = RouteSettings(name: '/training', arguments: 42);
      final Route<dynamic> route = AppRouter.buildRoute(
        RouteNames.training,
        builder,
        custom,
        MotionLevel.full,
      );
      expect(route.settings.name, '/training');
      expect(route.settings.arguments, 42);
    });
  });

  group('AppRouter 导航链路', () {
    testWidgets('已注册路由可正常 push', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      final AppRouter router = AppRouter(
        pages: const AppRoutePages.empty().withPages(<String, AppPageBuilder>{
          RouteNames.home: (BuildContext context, Object? arguments) => probe('首页'),
          RouteNames.settings: (BuildContext context, Object? arguments) => probe('设置页'),
        }),
        motionLevelResolver: () => MotionLevel.off,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          navigatorKey: navKey,
          initialRoute: RouteNames.home,
          onGenerateRoute: router.onGenerateRoute,
          onUnknownRoute: router.onUnknownRoute,
        ),
      );
      expect(find.text('首页'), findsOneWidget);

      navKey.currentState!.pushNamed<void>(RouteNames.settings);
      await tester.pumpAndSettle();
      expect(find.text('设置页'), findsOneWidget);
    });

    testWidgets('未注册路由落到占位页且可返回', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      final AppRouter router = AppRouter(
        pages: const AppRoutePages.empty().withPages(<String, AppPageBuilder>{
          RouteNames.home: (BuildContext context, Object? arguments) => probe('首页'),
        }),
        motionLevelResolver: () => MotionLevel.off,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          navigatorKey: navKey,
          initialRoute: RouteNames.home,
          onGenerateRoute: router.onGenerateRoute,
          onUnknownRoute: router.onUnknownRoute,
        ),
      );

      navKey.currentState!.pushNamed<void>(RouteNames.report);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.common.pageUnderConstruction), findsOneWidget);
      expect(find.text(RouteNames.report), findsNWidgets(2)); // AppBar + 正文
      expect(find.widgetWithText(OutlinedButton, AppStrings.common.back),
          findsOneWidget);

      // 占位页提供返回入口，导航链路完整。
      await tester.tap(find.widgetWithText(OutlinedButton, AppStrings.common.back));
      await tester.pumpAndSettle();
      expect(find.text('首页'), findsOneWidget);
    });

    testWidgets('resolverFor 在没有 MotionScope 时回落到 full', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          navigatorKey: navKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
      expect(AppRouter.resolverFor(navKey)(), MotionLevel.full);
    });

    testWidgets('未提供 resolver 时默认 full 档', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      const AppRouter router = AppRouter(pages: AppRoutePages.empty());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          navigatorKey: navKey,
          initialRoute: RouteNames.training,
          onGenerateRoute: router.onGenerateRoute,
          onUnknownRoute: router.onUnknownRoute,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoutePlaceholderPage), findsOneWidget);
    });
  });

  group('RoutePlaceholderPage', () {
    testWidgets('展示路由名与说明，且是完整可用页面', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const RoutePlaceholderPage(routeName: '/report'),
        ),
      );
      expect(find.text('/report'), findsNWidgets(2));
      expect(find.text(AppStrings.common.pageUnderConstruction), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('自定义 message 覆盖默认文案', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const RoutePlaceholderPage(
            routeName: '/x',
            message: '自定义提示',
          ),
        ),
      );
      expect(find.text('自定义提示'), findsOneWidget);
      expect(find.text(AppStrings.common.pageUnderConstruction), findsNothing);
    });

    testWidgets('栈底时不显示返回按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const RoutePlaceholderPage(routeName: '/x'),
        ),
      );
      expect(find.byType(BackButton), findsNothing);
      expect(find.widgetWithText(OutlinedButton, AppStrings.common.back),
          findsNothing);
    });
  });
}

/// 挂一棵最小的 widget 树，返回其中一个真实可用的 [BuildContext]。
Future<BuildContext> captureContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (BuildContext context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}
