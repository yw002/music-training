// T22 平台能力统一判断（架构 §2.7 / §5 验收 ⑥）。
//
// 验证 [PlatformCapabilities] 四档预设、语义化能力位、测试注入与相等性。
// 不依赖任何真实平台，全部走 [debugOverride] 注入。

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/platform/platform_capabilities.dart';

void main() {
  // 每个用例结束清掉注入，避免静态全局污染后续用例。
  tearDown(() => PlatformCapabilities.debugOverride(null));

  group('PlatformCapabilities 预设与能力位', () {
    test('mobile 预设：有触觉、无窗口、无键盘、非苹果', () {
      const PlatformCapabilities c = PlatformCapabilities.mobile();
      expect(c.isMobile, isTrue);
      expect(c.isDesktop, isFalse);
      expect(c.isWeb, isFalse);
      expect(c.isApple, isFalse);
      expect(c.hasHaptics, isTrue);
      expect(c.hasWindowChrome, isFalse);
      expect(c.hasKeyboard, isFalse);
      expect(c.usesMetaShortcuts, isFalse);
    });

    test('mobile apple(iOS)：仍是移动端，usesMetaShortcuts 为 false', () {
      const PlatformCapabilities c = PlatformCapabilities.mobile(apple: true);
      expect(c.isApple, isTrue);
      expect(c.isMobile, isTrue);
      expect(c.hasHaptics, isTrue);
      // 移动端不区分 ⌘/Ctrl，统一走 control 语义。
      expect(c.usesMetaShortcuts, isFalse);
    });

    test('desktop 预设：无触觉、有窗口、有键盘、非苹果用 Ctrl', () {
      const PlatformCapabilities c = PlatformCapabilities.desktop();
      expect(c.isMobile, isFalse);
      expect(c.isDesktop, isTrue);
      expect(c.hasHaptics, isFalse);
      expect(c.hasWindowChrome, isTrue);
      expect(c.hasKeyboard, isTrue);
      expect(c.usesMetaShortcuts, isFalse);
    });

    test('desktop apple(macOS)：usesMetaShortcuts 为 true（⌘）', () {
      const PlatformCapabilities c = PlatformCapabilities.desktop(apple: true);
      expect(c.isApple, isTrue);
      expect(c.usesMetaShortcuts, isTrue);
    });
  });

  group('PlatformCapabilities 测试注入', () {
    test('debugOverride 生效且可被 null 清除回到真实检测结果', () {
      final PlatformCapabilities original = PlatformCapabilities.current;
      // web 在原生测试环境下必与真实检测（mobile/desktop）不同，便于区分。
      PlatformCapabilities.debugOverride(const PlatformCapabilities.web());
      expect(PlatformCapabilities.current.isWeb, isTrue);
      PlatformCapabilities.debugOverride(null);
      // 清除后回到同一静态实例（[current] 缓存了 _detected）。
      expect(PlatformCapabilities.current, same(original));
    });
  });

  group('PlatformCapabilities 相等性', () {
    test('相等性与哈希仅由四个维度决定', () {
      const PlatformCapabilities a = PlatformCapabilities(
        isMobile: true,
        isDesktop: false,
        isWeb: false,
        isApple: false,
      );
      const PlatformCapabilities b = PlatformCapabilities(
        isMobile: true,
        isDesktop: false,
        isWeb: false,
        isApple: false,
      );
      const PlatformCapabilities c = PlatformCapabilities(
        isMobile: true,
        isDesktop: false,
        isWeb: false,
        isApple: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
