import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// 首页环境背景（M-06：4000ms 循环流动）。
///
/// 复用设计令牌里的环境渐变 [AppTokens.gradient]。`reduced` / `off` 档下停止
/// 循环、直接展示终态（渐变保持可见），符合架构 §8.4「跳过过程、保留终态」。
class AmbientBackground extends StatefulWidget {
  /// 创建环境背景。
  const AmbientBackground({super.key});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotionTokens.standard().home.ambientFlow.duration,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.allowAmbient) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 1; // 终态：背景可见、不循环
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final RadialGradient gradient = tokens.gradient.ambient;
    if (!context.allowAmbient) {
      return Container(decoration: BoxDecoration(gradient: gradient));
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double pulse =
            0.55 + 0.45 * (0.5 + 0.5 * math.sin(_controller.value * 2 * math.pi));
        return Opacity(
          opacity: pulse,
          child: Container(decoration: BoxDecoration(gradient: gradient)),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
