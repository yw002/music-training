import 'package:flutter/material.dart';

import 'package:interval_ear/core/motion/curves.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// Fade Through 转场。
///
/// 两个用途：
/// 1. 桌面端把 `M-01` / `M-02` 的容器变形降级为纯淡入淡出（架构 §1.6）；
/// 2. `MotionLevel.reduced` / `off` 时**所有**路由统一改用它（PRD §3.10）。
///
/// `off` 档位下时长为 0，即刻切换，但仍然走同一条代码路径，避免出现两套逻辑。
class FadeThroughPageRoute<T> extends PageRouteBuilder<T> {
  /// 创建 Fade Through 路由。
  FadeThroughPageRoute({
    required this.builder,
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
          transitionDuration: durationFor(motionLevel),
          reverseTransitionDuration: durationFor(motionLevel),
          opaque: true,
        );

  /// 目标页面构造器。
  final WidgetBuilder builder;

  /// 构造时的动效档位。
  final MotionLevel motionLevel;

  /// 该档位下的转场时长。
  ///
  /// `full` 走 `M-03` 的 reducedFade 参数（150ms linear），`off` 为 0。
  static Duration durationFor(MotionLevel level) {
    if (level == MotionLevel.off) {
      return Duration.zero;
    }
    return const AppMotionTokens.standard().transition.reducedFade.duration;
  }

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
    final Animation<double> fadeIn = CurvedAnimation(
      parent: animation,
      curve: AppCurve.linear,
    );
    final Animation<double> fadeOut = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppCurve.linear,
    );
    return FadeTransition(
      opacity: fadeIn,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(fadeOut),
        child: child,
      ),
    );
  }
}
