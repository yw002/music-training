import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interval_ear/app/app_dependencies.dart';
import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/settings/presentation/settings_cubit.dart';
import 'package:interval_ear/features/settings/presentation/settings_state.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';

/// 应用根 Widget。
///
/// 职责边界：
/// - 装配 `MaterialApp`（主题、路由、本地化）；
/// - 在 `builder` 内挂 [MotionScopeHost]（需要 `MediaQuery`）与文字缩放钳制；
/// - **不**做任何业务逻辑。
///
/// 主题模式与动效强度由 [SettingsCubit]（应用级状态源）驱动：改设置即时生效，
/// 无需重启（T17 验收）。
class IntervalEarApp extends StatelessWidget {
  /// 创建应用根。
  const IntervalEarApp({
    required this.dependencies,
    super.key,
  });

  /// 应用级依赖。
  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) => dependencies.providers(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          // 仅在「设置是否已加载」或「设置内容变化」时重建 MaterialApp，
          // 避免因其他状态子类切换而反复重建整棵应用树。
          buildWhen: (SettingsState previous, SettingsState next) =>
              previous is! SettingsLoaded ||
              next is! SettingsLoaded ||
              previous.settings != next.settings,
          builder: (BuildContext context, SettingsState state) {
            final AppSettings settings =
                state is SettingsLoaded ? state.settings : AppSettings.defaults;
            return MaterialApp(
              title: AppStrings.common.appName,
              debugShowCheckedModeBanner: false,
              navigatorKey: dependencies.navigatorKey,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: AppTheme.themeModeFor(settings.themeMode),
              initialRoute: RouteNames.home,
              onGenerateRoute: dependencies.router.onGenerateRoute,
              onUnknownRoute: dependencies.router.onUnknownRoute,
              builder: (BuildContext context, Widget? child) => AppShell(
                governorOwner: dependencies,
                motionPreference: settings.motionPreference,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
      );
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

  /// 用户动效偏好（来自 [SettingsCubit]）。
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
