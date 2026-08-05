import 'package:flutter/material.dart';

import 'package:interval_ear/core/motion/curves.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// Shared Axis 的三个轴向（Material Motion）。
enum SharedAxis {
  /// 水平推移：同层级平级页面之间（`M-03`）。
  x,

  /// 垂直推移：从属层级。
  y,

  /// 纵深缩放：进入结算 / 报告（`M-02`）。
  z;

  /// 该轴向的位移量（逻辑像素）；`z` 无位移，用缩放表达。
  double get travel => switch (this) {
        SharedAxis.x => 30,
        SharedAxis.y => 30,
        SharedAxis.z => 0,
      };
}

/// Shared Axis 转场（架构 §1.6，PRD `M-02` / `M-03`）。
///
/// - `SharedAxis.x`：`transition.standardPush`，300ms emphasized。
/// - `SharedAxis.z`：`transition.trainingToReport`，480ms emphasizedDecelerate，
///   并带 `M-02` 前置「成绩汇聚」240ms accelerate 相 —— 汇聚相由**训练页自身**
///   在 push 之前播放（它需要访问题目卡片的位置），本路由只负责主相。
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  /// 创建 Shared Axis 路由。
  SharedAxisPageRoute({
    required this.builder,
    required this.axis,
    this.motionLevel = MotionLevel.full,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              builder(context),
          transitionDuration: durationFor(axis, motionLevel),
          reverseTransitionDuration: durationFor(axis, motionLevel),
          opaque: true,
        );

  /// 目标页面构造器。
  final WidgetBuilder builder;

  /// 轴向。
  final SharedAxis axis;

  /// 构造时的动效档位。
  final MotionLevel motionLevel;

  /// 取该轴向对应的动效规格。
  static MotionSpec specFor(SharedAxis axis) {
    const AppMotionTokens tokens = AppMotionTokens.standard();
    return switch (axis) {
      SharedAxis.x || SharedAxis.y => tokens.transition.standardPush, // M-03
      SharedAxis.z => tokens.transition.trainingToReport, // M-02
    };
  }

  /// 取该轴向在指定档位下的时长。
  static Duration durationFor(SharedAxis axis, MotionLevel level) =>
      specFor(axis).effectiveDurationFor(level);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (motionLevel == MotionLevel.off) {
      return child;
    }
    final Curve curve =
        motionLevel == MotionLevel.full ? specFor(axis).curve : AppCurve.linear;
    final Animation<double> primary =
        CurvedAnimation(parent: animation, curve: curve);
    final Animation<double> secondary =
        CurvedAnimation(parent: secondaryAnimation, curve: curve);

    // reduced 档位只保留淡入淡出，不做位移 / 缩放（PRD §3.10）。
    if (motionLevel == MotionLevel.reduced) {
      return FadeTransition(
        opacity: primary,
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(secondary),
          child: child,
        ),
      );
    }

    if (axis == SharedAxis.z) {
      return FadeTransition(
        opacity: primary,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(primary),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.06).animate(secondary),
            child: child,
          ),
        ),
      );
    }

    final bool horizontal = axis == SharedAxis.x;
    final double travel = axis.travel;
    Offset enterBegin = Offset(travel, 0);
    Offset exitEnd = Offset(-travel, 0);
    if (!horizontal) {
      enterBegin = Offset(0, travel);
      exitEnd = Offset(0, -travel);
    }

    return FadeTransition(
      opacity: primary,
      child: _PixelSlide(
        animation: primary,
        begin: enterBegin,
        end: Offset.zero,
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(secondary),
          child: _PixelSlide(
            animation: secondary,
            begin: Offset.zero,
            end: exitEnd,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// `SharedAxis.x` 的便捷别名，对应架构路由表的 `SharedAxisXPageRoute`。
class SharedAxisXPageRoute<T> extends SharedAxisPageRoute<T> {
  /// 创建水平 Shared Axis 路由。
  SharedAxisXPageRoute({
    required super.builder,
    super.motionLevel,
    super.settings,
    super.fullscreenDialog,
  }) : super(axis: SharedAxis.x);
}

/// `SharedAxis.z` 的便捷别名，对应架构路由表的 `SharedAxisZPageRoute`。
class SharedAxisZPageRoute<T> extends SharedAxisPageRoute<T> {
  /// 创建纵深 Shared Axis 路由。
  SharedAxisZPageRoute({
    required super.builder,
    super.motionLevel,
    super.settings,
    super.fullscreenDialog,
  }) : super(axis: SharedAxis.z);
}

/// 以**逻辑像素**而非屏幕比例做位移的滑动，Shared Axis 规范要求 30dp 定值。
class _PixelSlide extends AnimatedWidget {
  const _PixelSlide({
    required Animation<double> animation,
    required this.begin,
    required this.end,
    required this.child,
  }) : super(listenable: animation);

  final Offset begin;
  final Offset end;
  final Widget child;

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final double t = _animation.value;
    final Offset offset = Offset(
      begin.dx + (end.dx - begin.dx) * t,
      begin.dy + (end.dy - begin.dy) * t,
    );
    return Transform.translate(offset: offset, child: child);
  }
}
