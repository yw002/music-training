import 'package:interval_ear/core/motion/motion_level.dart';

/// 把「用户偏好 + 系统开关 + 性能看门狗」三路输入归约成唯一的 [MotionLevel]。
///
/// 这是一个**纯函数**，没有任何 Flutter 依赖，因此可以用纯 Dart 单测跑完整真值表。
/// 所有组件都必须通过 `MotionScope` 读取它的结果，禁止各自判断。
abstract final class MotionLevelResolver {
  const MotionLevelResolver._();

  /// 归约规则（架构 §8.4 伪代码的逐行实现）：
  ///
  /// ```text
  /// if userSetting == off:                     return off
  /// if systemReduceMotion || governorDegraded: return reduced
  /// if userSetting == reduced:                 return reduced
  /// return full
  /// ```
  ///
  /// - [systemReduceMotion]：`MediaQuery.disableAnimations`，即系统「减弱动态效果」。
  /// - [userSetting]：设置页的 [MotionPreference]。
  /// - [governorDegraded]：`MotionGovernor` 因掉帧临时要求降级；它**不改写**用户设置。
  ///
  /// 注意与 PRD §3.10 的细微差别：PRD 表述为「当 `motionPreference == system` 时
  /// 才取系统开关」，按字面理解用户显式选 `full` 可以覆盖系统的减弱动效。架构 §8.4
  /// 把系统开关提到了 `full` 之前——这是无障碍上更安全的选择（用户在系统层面表达的
  /// 前庭敏感诉求不应被应用内设置悄悄绕过），本实现以架构 §8.4 为准。
  static MotionLevel resolve({
    required bool systemReduceMotion,
    required MotionPreference userSetting,
    required bool governorDegraded,
  }) {
    if (userSetting == MotionPreference.off) {
      return MotionLevel.off;
    }
    if (systemReduceMotion || governorDegraded) {
      return MotionLevel.reduced;
    }
    if (userSetting == MotionPreference.reduced) {
      return MotionLevel.reduced;
    }
    return MotionLevel.full;
  }
}
