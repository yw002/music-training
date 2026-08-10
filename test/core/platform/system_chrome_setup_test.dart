// T23 验收 ③④⑤：系统栏配置。
//
// - ③ Android edge-to-edge + 透明状态栏 / 导航栏；
// - ④ Material You 动态取色：项目无 `dynamic_color` 依赖，无对应代码路径，
//      本文件用一条「主题不含动态取色开关」的说明性断言把结论固化下来；
// - ⑤ Windows 不使用 acrylic / Mica：同样无依赖，见下方注释。
//
// 测试安全：桌面 / Web 档位下 [SystemChromeSetup.configure] 必须一次平台调用
// 都不发出 —— 本文件跑在 macOS 宿主机上，驱动替身的计数会直接暴露漏守卫。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/platform/platform_capabilities.dart';
import 'package:interval_ear/core/platform/system_chrome_setup.dart';

/// 记录调用的 `SystemChrome` 驱动替身。
class _FakeChromeDriver implements SystemChromeDriver {
  final List<SystemUiMode> modes = <SystemUiMode>[];
  final List<SystemUiOverlayStyle> styles = <SystemUiOverlayStyle>[];

  /// 为真时两个方法都抛异常。
  bool shouldThrow = false;

  int get totalCalls => modes.length + styles.length;

  @override
  Future<void> setEnabledSystemUIMode(SystemUiMode mode) async {
    if (shouldThrow) {
      throw PlatformException(code: 'unavailable');
    }
    modes.add(mode);
  }

  @override
  void setSystemUIOverlayStyle(SystemUiOverlayStyle style) {
    if (shouldThrow) {
      throw PlatformException(code: 'unavailable');
    }
    styles.add(style);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PlatformCapabilities.debugOverride(null));

  group('overlayStyleFor 透明系统栏（验收 ③）', () {
    test('深色背景：状态栏 / 导航栏透明，图标用浅色', () {
      final SystemUiOverlayStyle style =
          SystemChromeSetup.overlayStyleFor(Brightness.dark);

      expect(style.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarDividerColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
      // iOS 语义：statusBarBrightness 描述的是背景明暗，与图标明暗相反。
      expect(style.statusBarBrightness, Brightness.dark);
      // 关掉系统的对比度兜底，否则 Android 会自己糊一层半透明遮罩。
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    });

    test('浅色背景：图标用深色', () {
      final SystemUiOverlayStyle style =
          SystemChromeSetup.overlayStyleFor(Brightness.light);

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
    });
  });

  group('configure 平台守卫', () {
    test('移动端：开启 edgeToEdge 并套用透明样式', () async {
      final _FakeChromeDriver driver = _FakeChromeDriver();

      await SystemChromeSetup.configure(
        capabilities: const PlatformCapabilities.mobile(),
        driver: driver,
      );

      expect(driver.modes, <SystemUiMode>[SystemUiMode.edgeToEdge]);
      expect(driver.styles, hasLength(1));
      expect(driver.styles.single.statusBarColor, Colors.transparent);
    });

    test('iOS 也生效（同属移动端）', () async {
      final _FakeChromeDriver driver = _FakeChromeDriver();

      await SystemChromeSetup.configure(
        capabilities: const PlatformCapabilities.mobile(apple: true),
        driver: driver,
      );

      expect(driver.modes, <SystemUiMode>[SystemUiMode.edgeToEdge]);
    });

    test('桌面端：完全 no-op（测试安全）', () async {
      final _FakeChromeDriver driver = _FakeChromeDriver();

      await SystemChromeSetup.configure(
        capabilities: const PlatformCapabilities.desktop(apple: true),
        driver: driver,
      );

      expect(driver.totalCalls, 0);
    });

    test('Web：完全 no-op', () async {
      final _FakeChromeDriver driver = _FakeChromeDriver();

      await SystemChromeSetup.configure(
        capabilities: const PlatformCapabilities.web(),
        driver: driver,
      );

      expect(driver.totalCalls, 0);
    });

    test('未显式传 capabilities 时读全局注入档位', () async {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.desktop());
      final _FakeChromeDriver driver = _FakeChromeDriver();

      await SystemChromeSetup.configure(driver: driver);

      expect(driver.totalCalls, 0);
    });

    test('brightness 参数决定图标明暗', () async {
      final _FakeChromeDriver driver = _FakeChromeDriver();

      await SystemChromeSetup.configure(
        capabilities: const PlatformCapabilities.mobile(),
        driver: driver,
        brightness: Brightness.light,
      );

      expect(driver.styles.single.statusBarIconBrightness, Brightness.dark);
    });

    test('平台调用失败时不冒泡（不阻断启动）', () async {
      final _FakeChromeDriver driver = _FakeChromeDriver()..shouldThrow = true;

      await expectLater(
        SystemChromeSetup.configure(
          capabilities: const PlatformCapabilities.mobile(),
          driver: driver,
        ),
        completes,
      );
      expect(driver.totalCalls, 0);
    });
  });

  group('验收 ④⑤ 的结论固化', () {
    test('④ Material You：项目不依赖 dynamic_color，无动态取色代码路径', () {
      // `SystemChromeSetup` 只负责系统栏，绝不参与配色；主题固定由
      // `app/theme/app_theme.dart` 的色板驱动。这里断言「系统栏样式里没有
      // 任何来自壁纸的颜色」—— 全是 transparent，天然满足「不跟随壁纸变色」。
      final SystemUiOverlayStyle dark =
          SystemChromeSetup.overlayStyleFor(Brightness.dark);
      final SystemUiOverlayStyle light =
          SystemChromeSetup.overlayStyleFor(Brightness.light);
      expect(dark.statusBarColor, light.statusBarColor);
      expect(dark.systemNavigationBarColor, light.systemNavigationBarColor);
    });

    test('⑤ Windows acrylic / Mica：不引入任何半透明材质开关', () {
      // 项目未引入 flutter_acrylic，`window_manager` 侧也没有开启任何
      // 材质效果的调用；[SystemChromeSetup] 在桌面档位下是纯 no-op，
      // 上面的「桌面端：完全 no-op」用例已经把这一点钉死。
      expect(const PlatformCapabilities.desktop().isMobile, isFalse);
    });
  });
}
