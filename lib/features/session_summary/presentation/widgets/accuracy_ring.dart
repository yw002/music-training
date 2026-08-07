import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/curves.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 正确率环（CustomPainter，M-26 生长）。
///
/// 背景轨道 + 前景弧，弧从 0 生长到 [accuracy]。生长时长取 `report.chartGrow`
/// 的 520ms `emphasizedDecelerate`（M-26）；`reduced/off` 档跳过生长直达终态
/// （架构 §8.4，组件仍必须渲染终态）。
class AccuracyRing extends StatefulWidget {
  /// 创建正确率环。
  const AccuracyRing({required this.accuracy, this.size = 168, super.key});

  /// 正确率 [0, 1]。
  final double accuracy;

  /// 直径（逻辑像素）。
  final double size;

  @override
  State<AccuracyRing> createState() => _AccuracyRingState();
}

class _AccuracyRingState extends State<AccuracyRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _grow;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // duration 依赖 context.tokens（Theme.of），不能在 initState 读 inherited
    // widget，必须放到 didChangeDependencies 取（Flutter 框架约束 + 架构 §8.4）。
    _controller = AnimationController(vsync: this, duration: Duration.zero);
    _grow = CurvedAnimation(
      parent: _controller,
      curve: AppCurve.emphasizedDecelerate,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // M-26 生长：520ms emphasizedDecelerate，时长经 context.mDur 折算当前档位。
    _controller.duration =
        context.mDur(context.tokens.motion.report.barGrow.item.duration);
    if (_started) {
      return;
    }
    _started = true;
    if (context.motionLevel == MotionLevel.full) {
      _controller.forward();
    } else {
      // 降级档：跳过生长过程，直接展示终态（架构 §8.4）。
      _controller.value = _controller.upperBound;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final Color arcColor = widget.accuracy >= 0.6
        ? tokens.color.success.base
        : tokens.color.warning.base;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _AccuracyRingPainter(
          progress: widget.accuracy,
          grow: _grow.value,
          trackColor: tokens.scheme.surfaceContainerHighest,
          arcColor: arcColor,
          stroke: tokens.space.md,
        ),
      ),
    );
  }
}

/// 正确率环画笔：背景整圆 + 前景弧（从顶部顺时针生长 [AccuracyRing.accuracy]）。
class _AccuracyRingPainter extends CustomPainter {
  const _AccuracyRingPainter({
    required this.progress,
    required this.grow,
    required this.trackColor,
    required this.arcColor,
    required this.stroke,
  });

  final double progress;
  final double grow;
  final Color trackColor;
  final Color arcColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.shortestSide - stroke) / 2;

    // 背景轨道。
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // 前景弧：从顶部（-90°）顺时针生长 progress * grow 弧度。
    final double sweep = 2 * math.pi * progress * grow;
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = arcColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AccuracyRingPainter old) =>
      old.progress != progress ||
      old.grow != grow ||
      old.trackColor != trackColor ||
      old.arcColor != arcColor ||
      old.stroke != stroke;
}
