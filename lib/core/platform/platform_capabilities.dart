import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 平台能力的**唯一判断入口**（架构 §2.7 / §5 T22 验收 ⑥）。
///
/// 硬约束：除本文件外，`lib/` 下任何页面 / 组件都**禁止裸写 `Platform.isX`**。
/// 需要分平台行为时一律读 [PlatformCapabilities.current] 的语义化能力位：
///
/// | 能力 | 含义 | 典型用途 |
/// | --- | --- | --- |
/// | [hasHaptics] | 有振动马达（Android / iOS） | `AppHaptics` 桌面 no-op、设置页隐藏触觉开关 |
/// | [hasWindowChrome] | 有窗口装饰（Windows / macOS / Linux） | 桌面 tooltip（M-33）、窗口几何、文件选择器导出 |
/// | [hasKeyboard] | 常驻物理键盘 | 快捷键提示是否常驻展示 |
/// | [usesMetaShortcuts] | 主修饰键是 `⌘` 而非 `Ctrl` | `AppShortcuts.primaryModifier` |
///
/// 测试可用 [debugOverride] 注入替身档位，避免依赖宿主机真实平台。
@immutable
class PlatformCapabilities {
  /// 直接指定各维度（测试与预设构造器使用）。
  const PlatformCapabilities({
    required this.isMobile,
    required this.isDesktop,
    required this.isWeb,
    required this.isApple,
  });

  /// 移动端预设（[isApple] 为真表示 iOS）。
  const PlatformCapabilities.mobile({bool apple = false})
      : isMobile = true,
        isDesktop = false,
        isWeb = false,
        isApple = apple;

  /// 桌面端预设（[isApple] 为真表示 macOS）。
  const PlatformCapabilities.desktop({bool apple = false})
      : isMobile = false,
        isDesktop = true,
        isWeb = false,
        isApple = apple;

  /// Web 预设：无触觉、无窗口装饰、有键盘、非苹果。
  const PlatformCapabilities.web()
      : isMobile = false,
        isDesktop = false,
        isWeb = true,
        isApple = false;

  /// 是否移动端（Android / iOS）。
  final bool isMobile;

  /// 是否桌面端（Windows / macOS / Linux）。
  final bool isDesktop;

  /// 是否 Web。
  final bool isWeb;

  /// 是否 Apple 平台（macOS / iOS）。
  final bool isApple;

  static PlatformCapabilities? _override;

  static final PlatformCapabilities _detected = _detect();

  /// 当前运行平台的能力集合。
  static PlatformCapabilities get current => _override ?? _detected;

  /// 测试注入替身；传 `null` 恢复真实检测结果。
  @visibleForTesting
  static void debugOverride(PlatformCapabilities? capabilities) {
    _override = capabilities;
  }

  static PlatformCapabilities _detect() {
    if (kIsWeb) {
      return const PlatformCapabilities(
        isMobile: false,
        isDesktop: false,
        isWeb: true,
        isApple: false,
      );
    }
    return PlatformCapabilities(
      isMobile: Platform.isAndroid || Platform.isIOS,
      isDesktop: Platform.isWindows || Platform.isMacOS || Platform.isLinux,
      isWeb: false,
      isApple: Platform.isMacOS || Platform.isIOS,
    );
  }

  /// 是否具备触觉反馈硬件（桌面恒为 `false`）。
  bool get hasHaptics => isMobile;

  /// 是否具备窗口装饰 / 指针悬停（桌面恒为 `true`）。
  bool get hasWindowChrome => isDesktop;

  /// 是否具备常驻物理键盘。
  bool get hasKeyboard => isDesktop || isWeb;

  /// 主修饰键是否为 `⌘`（macOS）；否则为 `Ctrl`。
  bool get usesMetaShortcuts => isApple && !isMobile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformCapabilities &&
          other.isMobile == isMobile &&
          other.isDesktop == isDesktop &&
          other.isWeb == isWeb &&
          other.isApple == isApple;

  @override
  int get hashCode => Object.hash(isMobile, isDesktop, isWeb, isApple);

  @override
  String toString() => 'PlatformCapabilities(mobile: $isMobile, '
      'desktop: $isDesktop, web: $isWeb, apple: $isApple)';
}
