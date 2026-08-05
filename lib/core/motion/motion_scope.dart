import 'package:flutter/material.dart';

import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_level_resolver.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// `MotionScope` 向下广播的不可变数据。
@immutable
class MotionScopeData {
  /// 创建动效作用域数据。
  const MotionScopeData({
    required this.level,
    required this.stage,
    required this.userPreference,
    required this.systemReduceMotion,
  });

  /// 组件树未挂载 `MotionScope` 时的兜底：完整动效、无降级。
  ///
  /// 为什么给兜底而不是 assert：大量组件级 widget test 会单独渲染某个组件，
  /// 强制每个测试都包一层 Scope 只会让测试代码噪音变大，收益为零。
  const MotionScopeData.fallback()
      : level = MotionLevel.full,
        stage = MotionDegradeStage.none,
        userPreference = MotionPreference.system,
        systemReduceMotion = false;

  /// 当前生效档位。
  final MotionLevel level;

  /// 看门狗当前的降级级别。
  final MotionDegradeStage stage;

  /// 用户设置的偏好（用于设置页回显，不要用它来判断动画行为）。
  final MotionPreference userPreference;

  /// 系统「减弱动态效果」开关的当前值。
  final bool systemReduceMotion;

  /// 是否允许 ambient 循环动画。
  bool get allowAmbient => level.allowsAmbient;

  /// 是否允许粒子。看门狗把粒子降级到 0 时也返回 false。
  bool get allowParticles => level.allowsParticles;

  /// 是否允许 `BackdropFilter`（玻璃拟态）。
  bool get allowBackdropBlur =>
      level == MotionLevel.full && stage.allowsBackdropBlur;

  /// 是否被强制切换到极简可视化方案（`M-10`）。
  bool get forceMinimalVisualizer =>
      level != MotionLevel.full || stage.forcesMinimalVisualizer;

  /// 当前允许的粒子数上限。
  int particleLimit(MotionParticleSpec spec) => allowParticles
      ? spec.limitFor(degraded: stage.reducesParticles)
      : 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MotionScopeData &&
          other.level == level &&
          other.stage == stage &&
          other.userPreference == userPreference &&
          other.systemReduceMotion == systemReduceMotion);

  @override
  int get hashCode =>
      Object.hash(level, stage, userPreference, systemReduceMotion);

  @override
  String toString() => 'MotionScopeData(level: $level, stage: $stage)';
}

/// 全局广播当前动效档位的 `InheritedWidget`（架构 §1.8）。
class MotionScope extends InheritedWidget {
  /// 创建动效作用域。
  const MotionScope({
    required this.data,
    required super.child,
    super.key,
  });

  /// 当前数据。
  final MotionScopeData data;

  /// 读取最近的作用域；不存在时返回 [MotionScopeData.fallback]。
  static MotionScopeData of(BuildContext context) =>
      maybeOf(context) ?? const MotionScopeData.fallback();

  /// 读取最近的作用域；不存在时返回 `null`。
  static MotionScopeData? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MotionScope>()
      ?.data;

  @override
  bool updateShouldNotify(MotionScope oldWidget) => oldWidget.data != data;
}

/// 把「用户偏好 + 系统开关 + 看门狗」接起来，向下提供 [MotionScope]。
///
/// 放在 `MaterialApp.builder` 之下（需要 `MediaQuery`），包住整个页面树。
class MotionScopeHost extends StatefulWidget {
  /// 创建动效作用域宿主。
  const MotionScopeHost({
    required this.child,
    this.preference = MotionPreference.system,
    this.governor,
    super.key,
  });

  /// 子树。
  final Widget child;

  /// 用户设置的动效偏好。设置页变更后由上层重建传入。
  final MotionPreference preference;

  /// 性能看门狗。为 `null` 时不做性能降级（测试常用）。
  final MotionGovernor? governor;

  @override
  State<MotionScopeHost> createState() => _MotionScopeHostState();
}

class _MotionScopeHostState extends State<MotionScopeHost> {
  MotionDegradeStage _stage = MotionDegradeStage.none;

  @override
  void initState() {
    super.initState();
    final governor = widget.governor;
    if (governor != null) {
      _stage = governor.stage;
      governor.addListener(_onGovernorChanged);
    }
  }

  @override
  void didUpdateWidget(MotionScopeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.governor, widget.governor)) {
      oldWidget.governor?.removeListener(_onGovernorChanged);
      widget.governor?.addListener(_onGovernorChanged);
      _stage = widget.governor?.stage ?? MotionDegradeStage.none;
    }
  }

  @override
  void dispose() {
    widget.governor?.removeListener(_onGovernorChanged);
    super.dispose();
  }

  void _onGovernorChanged() {
    final next = widget.governor?.stage ?? MotionDegradeStage.none;
    if (next != _stage && mounted) {
      setState(() => _stage = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemReduceMotion = MediaQuery.disableAnimationsOf(context);
    final level = MotionLevelResolver.resolve(
      systemReduceMotion: systemReduceMotion,
      userSetting: widget.preference,
      governorDegraded: _stage.forcesReducedMotion,
    );
    return MotionScope(
      data: MotionScopeData(
        level: level,
        stage: _stage,
        userPreference: widget.preference,
        systemReduceMotion: systemReduceMotion,
      ),
      child: widget.child,
    );
  }
}

/// 动效降级的统一读取入口（架构 §1.8 / §8.4）。
///
/// **唯一正确姿势**：
/// ```dart
/// AnimatedContainer(
///   duration: context.mDur(context.tokens.motion.answerPress.duration), // ✅
///   // duration: const Duration(milliseconds: 90),                      // ❌
/// )
/// if (context.allowParticles) ConfettiLayer(...),                       // ✅
/// ```
extension MotionContextExtensions on BuildContext {
  /// 当前档位。
  MotionLevel get motionLevel => MotionScope.of(this).level;

  /// 当前作用域数据。
  MotionScopeData get motion => MotionScope.of(this);

  /// 是否允许 ambient 循环动画。
  bool get allowAmbient => MotionScope.of(this).allowAmbient;

  /// 是否允许粒子。
  bool get allowParticles => MotionScope.of(this).allowParticles;

  /// 是否允许 `BackdropFilter`。
  bool get allowBackdropBlur => MotionScope.of(this).allowBackdropBlur;

  /// 把完整时长折算成当前档位下的有效时长。
  Duration mDur(Duration full) => switch (motionLevel) {
        MotionLevel.full => full,
        MotionLevel.reduced =>
          full.inMilliseconds <= MotionLevel.reduced.maxDurationMs
              ? full
              : const Duration(milliseconds: 150),
        MotionLevel.off => Duration.zero,
      };

  /// 把完整规格折算成当前档位下的有效规格（时长 + 曲线）。
  MotionSpec mSpec(MotionSpec full) => full.effectiveFor(motionLevel);
}
