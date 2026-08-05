import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/radius.dart';
import 'package:interval_ear/core/motion/curves.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// Container Transform 转场（PRD `M-01` `transition.homeToTraining`）。
///
/// 「卡片变形为整页」：新页面从来源卡片的圆角矩形放大铺满，同时旧页面淡出。
/// 真正的**共享元素**（题号、音程名）由页面内的 `Hero` 承担，本路由只负责
/// 容器本身的形变 —— 这也是不用 `package:animations` 的 `OpenContainer` 的原因：
/// 我们需要完全掌控 `buildTransitions`（架构 §1.6）。
///
/// 420ms 进 / 340ms 出，`emphasized` 曲线。
class ContainerTransformPageRoute<T> extends PageRouteBuilder<T> {
  /// 创建容器变形路由。
  ContainerTransformPageRoute({
    required this.builder,
    this.motionLevel = MotionLevel.full,
    this.beginScale = 0.92,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              builder(context),
          transitionDuration: enterDurationFor(motionLevel),
          reverseTransitionDuration: exitDurationFor(motionLevel),
          opaque: true,
        );

  /// 目标页面构造器。
  final WidgetBuilder builder;

  /// 构造时的动效档位。
  final MotionLevel motionLevel;

  /// 起始缩放比例（模拟「卡片尺寸」）。
  final double beginScale;

  /// `M-01` 的两相规格。
  static MotionPairSpec get spec =>
      const AppMotionTokens.standard().transition.homeToTraining;

  /// 进入时长。
  static Duration enterDurationFor(MotionLevel level) =>
      spec.enter.effectiveDurationFor(level);

  /// 退出时长。
  static Duration exitDurationFor(MotionLevel level) =>
      spec.exit.effectiveDurationFor(level);

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

    final Animation<double> fade = CurvedAnimation(
      parent: animation,
      curve: AppCurve.linear,
    );

    // reduced 档位：教学内容不受影响，只把形变换成淡入（PRD §3.10）。
    if (motionLevel == MotionLevel.reduced) {
      return FadeTransition(opacity: fade, child: child);
    }

    final Animation<double> shaped = CurvedAnimation(
      parent: animation,
      curve: spec.enter.curve,
      reverseCurve: spec.exit.curve,
    );

    return AnimatedBuilder(
      animation: shaped,
      builder: (BuildContext context, Widget? inner) {
        final double t = shaped.value;
        final double scale = beginScale + (1 - beginScale) * t;
        final double radius = AppRadius.instance.bigCard.topLeft.x * (1 - t);
        return Transform.scale(
          scale: scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: inner,
          ),
        );
      },
      child: FadeTransition(opacity: fade, child: child),
    );
  }
}
