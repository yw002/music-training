import 'package:flutter/material.dart';

import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/app/router/transitions/container_transform_route.dart';
import 'package:interval_ear/app/router/transitions/fade_through_route.dart';
import 'package:interval_ear/app/router/transitions/shared_axis_route.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/utils/app_logger.dart';

/// 页面构造器。`arguments` 为 `Navigator.pushNamed` 传入的参数。
typedef AppPageBuilder = Widget Function(
  BuildContext context,
  Object? arguments,
);

/// 路由名 → 页面构造器 的登记表。
///
/// 功能页面由各自的 feature 任务实现后在 `AppDependencies` 组装时注入，
/// 未注入的路由回落到 [RoutePlaceholderPage]。这样 `app/` 层不需要在编译期
/// 依赖 `features/`，路由骨架可以先于页面落地并被单测覆盖。
@immutable
class AppRoutePages {
  /// 用给定登记表创建。
  const AppRoutePages(this.builders);

  /// 空表：全部路由走占位页。
  const AppRoutePages.empty() : builders = const <String, AppPageBuilder>{};

  /// 登记表。
  final Map<String, AppPageBuilder> builders;

  /// 追加 / 覆盖若干路由。
  AppRoutePages withPages(Map<String, AppPageBuilder> pages) => AppRoutePages(
        <String, AppPageBuilder>{...builders, ...pages},
      );

  /// 取构造器；未登记时返回占位页构造器。
  AppPageBuilder resolve(String routeName) =>
      builders[routeName] ??
      (BuildContext context, Object? arguments) =>
          RoutePlaceholderPage(routeName: routeName);
}

/// 集中式路由器（架构 §1.6）。
///
/// `MotionLevel.reduced / off` 时统一改用 `FadeThroughPageRoute`，判断只发生在
/// 这里，不在每个页面里重复（PRD §3.10）。
@immutable
class AppRouter {
  /// 创建路由器。
  ///
  /// [motionLevelResolver] 用于在 `onGenerateRoute`（无 `BuildContext`）中读取
  /// 当前档位；生产环境由 `IntervalEarApp` 传入基于 `navigatorKey` 的实现，
  /// 单测可直接传常量函数。
  const AppRouter({
    this.pages = const AppRoutePages.empty(),
    this.motionLevelResolver,
  });

  /// 页面登记表。
  final AppRoutePages pages;

  /// 当前档位解析器；为 `null` 时按 `full` 处理。
  final MotionLevel Function()? motionLevelResolver;

  /// 由 `navigatorKey` 读取当前档位的解析器工厂。
  static MotionLevel Function() resolverFor(
    GlobalKey<NavigatorState> navigatorKey,
  ) =>
      () {
        final BuildContext? context = navigatorKey.currentContext;
        if (context == null) {
          return MotionLevel.full;
        }
        return MotionScope.of(context).level;
      };

  /// 当前动效档位。
  MotionLevel get motionLevel =>
      motionLevelResolver?.call() ?? MotionLevel.full;

  /// `MaterialApp.onGenerateRoute`。
  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final String name = settings.name ?? RouteNames.home;
    if (!RouteNames.isKnown(name)) {
      return onUnknownRoute(settings);
    }
    final AppPageBuilder pageBuilder = pages.resolve(name);
    final Object? arguments = settings.arguments;
    Widget build(BuildContext context) => pageBuilder(context, arguments);
    return buildRoute(name, build, settings, motionLevel);
  }

  /// `MaterialApp.onUnknownRoute`：不崩溃，落到占位页并记一条 warning。
  Route<dynamic> onUnknownRoute(RouteSettings settings) {
    AppLogger.warning(
      'unknown route: ${settings.name}',
      tag: 'AppRouter',
    );
    return FadeThroughPageRoute<void>(
      settings: settings,
      motionLevel: motionLevel,
      builder: (BuildContext context) => RoutePlaceholderPage(
        routeName: settings.name ?? '',
        message: AppStrings.common.unknownRoute,
      ),
    );
  }

  /// 路由名 → `PageRoute` 的映射（架构 §1.6 路由表）。公开以便单测直接断言。
  static Route<dynamic> buildRoute(
    String name,
    WidgetBuilder builder,
    RouteSettings settings,
    MotionLevel level,
  ) {
    // PRD §3.10：非 full 档位统一淡入淡出，150ms linear（off 为 0ms）。
    if (level != MotionLevel.full) {
      return FadeThroughPageRoute<void>(
        builder: builder,
        motionLevel: level,
        settings: settings,
      );
    }
    return switch (name) {
      RouteNames.training || RouteNames.binaryTraining =>
        ContainerTransformPageRoute<void>( // M-01
          builder: builder,
          motionLevel: level,
          settings: settings,
        ),
      RouteNames.sessionSummary => SharedAxisZPageRoute<void>( // M-02
          builder: builder,
          motionLevel: level,
          settings: settings,
        ),
      RouteNames.home => FadeThroughPageRoute<void>(
          builder: builder,
          motionLevel: level,
          settings: settings,
        ),
      _ => SharedAxisXPageRoute<void>( // M-03
          builder: builder,
          motionLevel: level,
          settings: settings,
        ),
    };
  }
}

/// 路由已登记但页面尚未接入时展示的占位页。
///
/// 这是一个**完整可用**的页面（不是空壳）：显示路由名与说明，并提供返回入口，
/// 便于在功能页面落地之前就把导航链路跑通并写成 widget test。
class RoutePlaceholderPage extends StatelessWidget {
  /// 创建占位页。
  const RoutePlaceholderPage({
    required this.routeName,
    this.message,
    super.key,
  });

  /// 当前路由名。
  final String routeName;

  /// 自定义说明文案；为空时使用「该页面正在开发中」。
  final String? message;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(title: Text(routeName)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message ?? AppStrings.common.pageUnderConstruction,
                style: tokens.type.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.space.md),
              Text(
                routeName,
                style: tokens.type.bodySmall?.copyWith(
                  color: tokens.scheme.onSurfaceVariant,
                ),
              ),
              if (canPop) ...<Widget>[
                SizedBox(height: tokens.space.lg),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(AppStrings.common.back),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
