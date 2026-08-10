import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:interval_ear/core/platform/platform_capabilities.dart';

/// 触觉强度四档（PRD §5.11）。
///
/// 明确**不提供** `HapticFeedback.vibrate()`：PRD 表格里它是全局禁止项
/// （过重、体感突兀）。
enum HapticLevel {
  /// 极轻：按钮按下、chip 切换、滑块跨刻度、开关。
  selection,

  /// 轻：播放开始、答对、重播。
  light,

  /// 中：答错、连击达成（3/5/10）。
  medium,

  /// 重：一组训练完成、清空数据确认成功。
  heavy,
}

/// 触觉执行驱动。抽出接口是为了让 widget test 不打平台通道即可断言调用序列。
abstract interface class HapticDriver {
  /// 执行一次指定强度的触觉反馈。
  Future<void> perform(HapticLevel level);
}

/// 走 Flutter `HapticFeedback` 平台通道的默认驱动。
class SystemHapticDriver implements HapticDriver {
  /// 创建系统驱动。
  const SystemHapticDriver();

  @override
  Future<void> perform(HapticLevel level) => switch (level) {
        HapticLevel.selection => HapticFeedback.selectionClick(),
        HapticLevel.light => HapticFeedback.lightImpact(),
        HapticLevel.medium => HapticFeedback.mediumImpact(),
        HapticLevel.heavy => HapticFeedback.heavyImpact(),
      };
}

/// 触觉反馈统一封装（架构 §1.4 T22 / §5 T22 验收 ⑤）。
///
/// 两道门都通过才会真的振动：
/// 1. [enabled]：用户设置 `AppSettings.hapticsEnabled`（默认 `true`）；
/// 2. `PlatformCapabilities.hasHaptics`：**桌面端恒为 no-op**，不抛异常、
///    不产生日志噪声（PRD §5.11 明确要求）。
///
/// 用法：
/// ```dart
/// final AppHaptics haptics = AppHaptics(enabled: settings.hapticsEnabled);
/// await haptics.selection(); // 按下答案按钮
/// ```
@immutable
class AppHaptics {
  /// 创建触觉封装。
  ///
  /// [capabilities] 留空则读 [PlatformCapabilities.current]；
  /// [driver] 留空则走真实平台通道。
  const AppHaptics({
    this.enabled = true,
    this.capabilities,
    this.driver = const SystemHapticDriver(),
  });

  /// 用户是否开启触觉（对应 `AppSettings.hapticsEnabled`）。
  final bool enabled;

  /// 平台能力覆盖（测试用）。
  final PlatformCapabilities? capabilities;

  /// 执行驱动。
  final HapticDriver driver;

  PlatformCapabilities get _capabilities =>
      capabilities ?? PlatformCapabilities.current;

  /// 当前是否真的会产生振动（用户开启 **且** 平台有触觉硬件）。
  bool get isActive => enabled && _capabilities.hasHaptics;

  /// 极轻档。
  Future<void> selection() => _fire(HapticLevel.selection);

  /// 轻档。
  Future<void> light() => _fire(HapticLevel.light);

  /// 中档。
  Future<void> medium() => _fire(HapticLevel.medium);

  /// 重档。
  Future<void> heavy() => _fire(HapticLevel.heavy);

  /// 按枚举触发（供表驱动调用）。
  Future<void> perform(HapticLevel level) => _fire(level);

  Future<void> _fire(HapticLevel level) async {
    if (!isActive) {
      return;
    }
    await driver.perform(level);
  }

  /// 复制并覆盖开关（设置项变化时用）。
  AppHaptics copyWith({bool? enabled}) => AppHaptics(
        enabled: enabled ?? this.enabled,
        capabilities: capabilities,
        driver: driver,
      );
}
