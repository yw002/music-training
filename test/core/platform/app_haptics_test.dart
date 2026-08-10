// T22 触觉封装（架构 §1.4 / §5 验收 ⑤）。
//
// 验证 [AppHaptics] 移动端四档触发、桌面端恒为 no-op、开关关闭不触发，
// 以及驱动调用序列可通过 [HapticDriver] 接口断言（不打平台通道）。

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/platform/app_haptics.dart';
import 'package:interval_ear/core/platform/platform_capabilities.dart';

/// 记录所有被请求的触觉档位，用于断言。
class _FakeHapticDriver implements HapticDriver {
  final List<HapticLevel> calls = <HapticLevel>[];

  @override
  Future<void> perform(HapticLevel level) async => calls.add(level);
}

void main() {
  tearDown(() => PlatformCapabilities.debugOverride(null));

  group('AppHaptics 触发行为', () {
    test('移动端 + 开启：四档全部触发驱动', () async {
      final _FakeHapticDriver driver = _FakeHapticDriver();
      final AppHaptics haptics = AppHaptics(
        enabled: true,
        capabilities: const PlatformCapabilities.mobile(),
        driver: driver,
      );
      expect(haptics.isActive, isTrue);

      await haptics.selection();
      await haptics.light();
      await haptics.medium();
      await haptics.heavy();
      await haptics.perform(HapticLevel.selection);

      expect(driver.calls, <HapticLevel>[
        HapticLevel.selection,
        HapticLevel.light,
        HapticLevel.medium,
        HapticLevel.heavy,
        HapticLevel.selection,
      ]);
    });

    test('桌面端：恒为 no-op，不调用驱动、不抛异常', () async {
      final _FakeHapticDriver driver = _FakeHapticDriver();
      final AppHaptics haptics = AppHaptics(
        enabled: true,
        capabilities: const PlatformCapabilities.desktop(),
        driver: driver,
      );
      expect(haptics.isActive, isFalse);

      await haptics.selection();
      await haptics.light();
      await haptics.medium();
      await haptics.heavy();

      expect(driver.calls, isEmpty);
    });

    test('关闭触觉：任何平台都不触发', () async {
      final _FakeHapticDriver driver = _FakeHapticDriver();
      final AppHaptics haptics = AppHaptics(
        enabled: false,
        capabilities: const PlatformCapabilities.mobile(),
        driver: driver,
      );
      expect(haptics.isActive, isFalse);

      await haptics.selection();

      expect(driver.calls, isEmpty);
    });
  });

  group('AppHaptics 配置', () {
    test('enabled=false 时 isActive 为 false', () {
      final AppHaptics haptics = AppHaptics(
        enabled: false,
        capabilities: const PlatformCapabilities.mobile(),
      );
      expect(haptics.isActive, isFalse);
    });

    test('copyWith 仅覆盖 enabled 且保持能力位', () {
      final AppHaptics haptics = AppHaptics(
        enabled: true,
        capabilities: const PlatformCapabilities.mobile(),
      );
      final AppHaptics copied = haptics.copyWith(enabled: false);
      expect(copied.enabled, isFalse);
      expect(copied.isActive, isFalse);
      // 能力位未变（仍是移动端有触觉），只是开关关了。
      expect(copied.capabilities, const PlatformCapabilities.mobile());
    });
  });
}
