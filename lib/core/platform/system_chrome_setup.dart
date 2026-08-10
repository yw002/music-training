import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:interval_ear/core/platform/platform_capabilities.dart';
import 'package:interval_ear/core/utils/app_logger.dart';

/// `SystemChrome` 调用驱动（抽出接口，让测试不打平台通道也能断言调用）。
abstract interface class SystemChromeDriver {
  /// 设置系统 UI 模式（edge-to-edge / 沉浸等）。
  Future<void> setEnabledSystemUIMode(SystemUiMode mode);

  /// 设置状态栏 / 导航栏样式。
  void setSystemUIOverlayStyle(SystemUiOverlayStyle style);
}

/// 走 Flutter `SystemChrome` 的默认驱动。
class PlatformSystemChromeDriver implements SystemChromeDriver {
  /// 创建默认驱动。
  const PlatformSystemChromeDriver();

  @override
  Future<void> setEnabledSystemUIMode(SystemUiMode mode) =>
      SystemChrome.setEnabledSystemUIMode(mode);

  @override
  void setSystemUIOverlayStyle(SystemUiOverlayStyle style) =>
      SystemChrome.setSystemUIOverlayStyle(style);
}

/// 系统栏配置（架构 §2.8 T23 / 验收 ③④⑤）。
///
/// 三条平台结论，写在这里以免后人反复考古：
///
/// 1. **Android edge-to-edge + 透明系统栏**（验收 ③）：
///    `SystemUiMode.edgeToEdge` + 状态栏/导航栏 `transparent`，
///    配合 `AndroidManifest.xml` 的 `io.flutter.embedding.android.EdgeToEdge`
///    与 `styles.xml` 的 `windowLayoutInDisplayCutoutMode=shortEdges`
///    共同生效；内容避让由页面侧的 `SafeArea` 负责。
/// 2. **Material You 动态取色（验收 ④）：本项目无需处理。**
///    `pubspec.yaml` **没有** `dynamic_color` 依赖，主题完全由
///    `app/theme/app_theme.dart` 的固定色板驱动，不存在「跟随壁纸变色」的
///    代码路径，因此「关闭动态取色」没有对应实现点 —— 现状即已满足。
/// 3. **Windows 不使用 acrylic / Mica（验收 ⑤）：本项目无需处理。**
///    未引入 `flutter_acrylic` 等库，`window_manager` 也未开启任何
///    半透明材质，窗口是标准不透明背景。
///
/// 调用位置限制：**只允许在 `AppBootstrap` 启动路径调用**，绝不能进页面
/// widget（否则 widget test 会打平台通道）。非移动端直接 no-op。
abstract final class SystemChromeSetup {
  const SystemChromeSetup._();

  /// 日志 tag。
  static const String logTag = 'SystemChrome';

  /// 生成透明系统栏样式。
  ///
  /// [brightness] 是**应用背景**的明暗：背景深 → 图标用浅色，背景浅 →
  /// 图标用深色。`statusBarIconBrightness` 是 Android 语义（图标本身的明暗），
  /// `statusBarBrightness` 是 iOS 语义（状态栏背景的明暗），两者取值相反，
  /// 这里一次性给对，避免调用方踩坑。
  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Brightness iconBrightness =
        isDark ? Brightness.light : Brightness.dark;
    // 说明：这里的 transparent 是「让系统栏透出应用内容」的平台开关，
    // 不是主题配色，故不走 design token（token 里也没有该语义）。
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: brightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarContrastEnforced: false,
    );
  }

  /// 应用 edge-to-edge 与透明系统栏。
  ///
  /// 仅移动端生效；桌面 / Web 直接返回（它们没有系统状态栏，调用只会白白
  /// 打一次平台通道）。失败只记日志，不阻断启动。
  static Future<void> configure({
    PlatformCapabilities? capabilities,
    SystemChromeDriver driver = const PlatformSystemChromeDriver(),
    Brightness brightness = Brightness.dark,
  }) async {
    final PlatformCapabilities caps =
        capabilities ?? PlatformCapabilities.current;
    if (!caps.isMobile) {
      return;
    }
    try {
      await driver.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      driver.setSystemUIOverlayStyle(overlayStyleFor(brightness));
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'edge-to-edge 配置失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
