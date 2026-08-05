import 'package:flutter/material.dart';

import 'package:interval_ear/app/router/app_router.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';

/// 应用级依赖容器（架构 §1.4 手写依赖装配，不引 DI 框架）。
///
/// 只装「进程内单例、跨页面共享、生命周期与 App 等长」的对象。页面级
/// Bloc / Cubit 由各自 feature 在 `BlocProvider` 里创建，不进这里。
///
/// 装配顺序固定为：基础设施（日志 / 存储）→ 领域服务 → 表现层（路由）。
/// 后续任务往里加字段时，请保持 [dispose] 的释放顺序与创建顺序相反。
@immutable
class AppDependencies {
  /// 直接构造（测试可传入替身）。
  const AppDependencies({
    required this.navigatorKey,
    required this.motionGovernor,
    required this.router,
  });

  /// 全局 Navigator key。`AppRouter` 借它在无 `BuildContext` 时读动效档位。
  final GlobalKey<NavigatorState> navigatorKey;

  /// 帧性能看门狗（架构 §1.8）。
  final MotionGovernor motionGovernor;

  /// 集中式路由器。
  final AppRouter router;

  /// 生产环境装配。
  ///
  /// [pages] 为功能页面登记表；随着 feature 任务落地逐步填充，未登记的路由
  /// 会回落到 `RoutePlaceholderPage`，不会崩溃。
  static Future<AppDependencies> bootstrap({
    AppRoutePages pages = const AppRoutePages.empty(),
    bool startGovernor = true,
  }) async {
    final GlobalKey<NavigatorState> navigatorKey =
        GlobalKey<NavigatorState>(debugLabel: 'appNavigator');
    final MotionGovernor governor = MotionGovernor();
    if (startGovernor) {
      governor.start();
    }
    final AppRouter router = AppRouter(
      pages: pages,
      motionLevelResolver: AppRouter.resolverFor(navigatorKey),
    );
    return AppDependencies(
      navigatorKey: navigatorKey,
      motionGovernor: governor,
      router: router,
    );
  }

  /// 替换页面登记表（feature 模块接入时使用），其余依赖原样保留。
  AppDependencies withPages(Map<String, AppPageBuilder> pages) =>
      AppDependencies(
        navigatorKey: navigatorKey,
        motionGovernor: motionGovernor,
        router: AppRouter(
          pages: router.pages.withPages(pages),
          motionLevelResolver: AppRouter.resolverFor(navigatorKey),
        ),
      );

  /// 释放资源；顺序与创建顺序相反。
  void dispose() {
    motionGovernor
      ..stop()
      ..dispose();
  }
}
