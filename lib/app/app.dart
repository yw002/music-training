import 'package:flutter/material.dart';

import 'package:interval_ear/app/app_dependencies.dart';
import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 应用根 Widget。
///
/// 职责边界：
/// - 装配 `MaterialApp`（主题、路由、本地化）；
/// - 在 `builder` 内挂 [MotionScopeHost]（需要 `MediaQuery`）与文字缩放钳制；
/// - **不**做任何业务逻辑。
class IntervalEarApp extends StatefulWidget {
  /// 创建应用根。
  const IntervalEarApp({
    required this.dependencies,
    this.themeMode = ThemeMode.dark,
    this.motionPreference = MotionPreference.system,
    super.key,
  });

  /// 应用级依赖。
  final AppDependencies dependencies;

  /// 主题模式。PRD 把深色定为推荐默认体验。
  final ThemeMode themeMode;

  /// 用户动效偏好（设置页落地后由 SettingsBloc 驱动）。
  final MotionPreference motionPreference;

  @override
  State<IntervalEarApp> createState() => _IntervalEarAppState();
}

class _IntervalEarAppState extends State<IntervalEarApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.common.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: widget.dependencies.navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.themeMode,
      initialRoute: RouteNames.home,
      onGenerateRoute: widget.dependencies.router.onGenerateRoute,
      onUnknownRoute: widget.dependencies.router.onUnknownRoute,
      builder: (BuildContext context, Widget? child) => AppShell(
        governorOwner: widget.dependencies,
        motionPreference: widget.motionPreference,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// `MaterialApp.builder` 里插入的公共外壳。
///
/// 单独拆出来是为了让 widget test 可以不启动整个 `MaterialApp` 就复用同一套
/// 文字缩放钳制 + 动效作用域逻辑。
class AppShell extends StatelessWidget {
  /// 创建外壳。
  const AppShell({
    required this.child,
    required this.governorOwner,
    this.motionPreference = MotionPreference.system,
    super.key,
  });

  /// 子树。
  final Widget child;

  /// 持有看门狗的依赖容器。
  final AppDependencies governorOwner;

  /// 用户动效偏好。
  final MotionPreference motionPreference;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    // PRD §2.3：文字缩放上限 clamp(1.0, 1.3)。
    final MediaQueryData clamped = media.copyWith(
      textScaler: media.textScaler.clamp(
        minScaleFactor: AppConfig.minTextScale,
        maxScaleFactor: AppConfig.maxTextScale,
      ),
    );
    return MediaQuery(
      data: clamped,
      child: MotionScopeHost(
        preference: motionPreference,
        governor: governorOwner.motionGovernor,
        child: child,
      ),
    );
  }
}
