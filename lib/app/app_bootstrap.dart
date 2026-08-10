import 'dart:async';
import 'dart:ui' show PlatformDispatcher, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:interval_ear/app/app.dart';
import 'package:interval_ear/app/app_dependencies.dart';
import 'package:interval_ear/app/app_lifecycle_handler.dart';
import 'package:interval_ear/app/router/app_pages.dart';
import 'package:interval_ear/app/router/app_router.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/platform/platform_capabilities.dart';
import 'package:interval_ear/core/platform/system_chrome_setup.dart';
import 'package:interval_ear/core/platform/window_setup.dart';
import 'package:interval_ear/core/utils/app_logger.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';
import 'package:window_manager/window_manager.dart';

/// 应用启动流程（架构 §1.4）。
///
/// 顺序：绑定初始化 → 全局错误兜底 → 依赖装配 → 桌面窗口 → 系统栏 → `runApp`。
/// 任何一步失败都**不允许**让进程静默退出：错误会写进 [AppLogger]，
/// 并让 App 以降级状态继续启动（例如窗口设置失败不影响业务）。
///
/// T23 起「依赖装配」被前置到「桌面窗口」之前 —— 窗口几何要从
/// [SettingsRepository] 读回（验收 ②），关窗收尾要用到
/// [AppLifecycleHandler]（验收 ①⑥），两者都依赖装配结果。代价是窗口出现得
/// 稍晚一点点（多等一次本地文件读取），换来的是「不会先弹默认尺寸再跳到
/// 记忆尺寸」的无闪跳体验。
abstract final class AppBootstrap {
  /// 启动应用。
  static Future<void> run({
    AppRoutePages pages = const AppRoutePages.empty(),
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    installErrorHandlers();

    final AppDependencies dependencies =
        await AppDependencies.bootstrap(pages: pages);

    // 进程级生命周期处理器：退到后台 / 关窗时停音频 + 标记 aborted + flush。
    // 这里只创建，真正 attach 交给 App 根 [IntervalEarApp]（架构 §2.8 要求
    // 「绝不可挂进页面 widget」，App 根是唯一合法挂载点）。
    final AppLifecycleHandler lifecycleHandler = AppLifecycleHandler(
      audio: dependencies.audio,
      repository: dependencies.trainingRepo,
      sessions: dependencies.activeSessions,
    );

    // 桌面：恢复窗口几何 + 挂 resize/move/close 监听。
    // `onWindowClose` 与生命周期回调共用同一个幂等的 `handleShutdown`，
    // 构成架构 §8 风险点 7 要求的「Windows 关窗 flush 双重保险」。
    await configureDesktopWindow(
      settingsRepo: dependencies.settingsRepo,
      onWindowClose: lifecycleHandler.handleShutdown,
    );

    // 移动端：edge-to-edge + 透明系统栏（验收 ③）；桌面 / Web 内部直接 no-op。
    await SystemChromeSetup.configure();

    // 默认注入本批次已落地的功能页；测试仍可显式传入自定义 pages 覆盖。
    final AppRoutePages effectivePages =
        pages.builders.isEmpty ? buildFeaturePages(dependencies) : pages;
    runApp(
      IntervalEarApp(
        dependencies: dependencies.withPages(effectivePages.builders),
        lifecycleHandler: lifecycleHandler,
      ),
    );
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
  ///
  /// 统一走 [PlatformCapabilities]（架构 §2.7：`lib/` 内禁止裸写 `Platform.isX`），
  /// 测试可用 `PlatformCapabilities.debugOverride` 改档位。
  static bool get isDesktop => PlatformCapabilities.current.hasWindowChrome;

  /// 桌面端窗口初始化（架构 §7.4 `window_manager` / T23 验收 ②）。
  ///
  /// 移动端直接返回 `null`，**不触碰任何 `window_manager` API** —— 这保证在
  /// macOS 宿主机上跑 widget test 时，只要不调用本方法就不会打桌面平台通道。
  ///
  /// 桌面端流程：
  /// 1. `ensureInitialized()`；
  /// 2. 设最小尺寸 900×640、默认尺寸、居中、标准标题栏、窗口标题；
  /// 3. 在 `show()` **之前** 恢复上次的窗口几何（[configureWindowGeometry]），
  ///    避免「先默认尺寸、再跳到记忆尺寸」的闪跳；
  /// 4. `show()` + `focus()`。
  ///
  /// [settingsRepo] 为空时跳过几何恢复（仅套用默认尺寸），便于集成测试。
  /// 失败只记日志，不阻断启动 —— 一个窗口尺寸设不上不该让用户打不开 App。
  ///
  /// 返回窗口几何控制器（移动端 / 失败时为 `null`），调用方可在退出时
  /// `detach()`。
  static Future<WindowGeometryController?> configureDesktopWindow({
    SettingsRepository? settingsRepo,
    Future<void> Function()? onWindowClose,
  }) async {
    if (!isDesktop) {
      return null;
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
      WindowGeometryController? controller;
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setTitle(AppStrings.common.appName);
        if (settingsRepo != null) {
          controller = await configureWindowGeometry(
            settingsRepo,
            onClose: onWindowClose,
          );
        }
        await windowManager.show();
        await windowManager.focus();
      });
      return controller;
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'desktop window init failed',
        tag: 'AppBootstrap',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
