import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:interval_ear/app/app.dart';
import 'package:interval_ear/app/app_dependencies.dart';
import 'package:interval_ear/app/router/app_router.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/utils/app_logger.dart';
import 'package:window_manager/window_manager.dart';

/// 应用启动流程（架构 §1.4）。
///
/// 顺序：绑定初始化 → 全局错误兜底 → 桌面窗口 → 依赖装配 → `runApp`。
/// 任何一步失败都**不允许**让进程静默退出：错误会写进 [AppLogger]，
/// 并让 App 以降级状态继续启动（例如窗口设置失败不影响业务）。
abstract final class AppBootstrap {
  /// 启动应用。
  static Future<void> run({
    AppRoutePages pages = const AppRoutePages.empty(),
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    installErrorHandlers();
    await configureDesktopWindow();
    final AppDependencies dependencies =
        await AppDependencies.bootstrap(pages: pages);
    runApp(IntervalEarApp(dependencies: dependencies));
  }

  /// 安装全局错误兜底。
  ///
  /// 分开成独立方法便于集成测试单独调用。
  static void installErrorHandlers() {
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error(
        details.exceptionAsString(),
        tag: 'FlutterError',
        error: details.exception,
        stackTrace: details.stack,
      );
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLogger.error(
        error.toString(),
        tag: 'PlatformDispatcher',
        error: error,
        stackTrace: stack,
      );
      return true;
    };
  }

  /// 是否运行在桌面端。
  static bool get isDesktop {
    if (kIsWeb) {
      return false;
    }
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 桌面端窗口初始化（架构 §7.4 `window_manager`）。
  ///
  /// 移动端直接返回；桌面端设置最小尺寸、默认尺寸与标题。失败只记日志，
  /// 不阻断启动 —— 一个窗口尺寸设不上不该让用户打不开 App。
  static Future<void> configureDesktopWindow() async {
    if (!isDesktop) {
      return;
    }
    try {
      await windowManager.ensureInitialized();
      const WindowOptions options = WindowOptions(
        size: Size(
          AppConfig.desktopDefaultWidth,
          AppConfig.desktopDefaultHeight,
        ),
        minimumSize: Size(
          AppConfig.desktopMinWidth,
          AppConfig.desktopMinHeight,
        ),
        center: true,
        titleBarStyle: TitleBarStyle.normal,
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setTitle(AppStrings.common.appName);
        await windowManager.show();
        await windowManager.focus();
      });
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'desktop window init failed',
        tag: 'AppBootstrap',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
