import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 正确率环画笔（报告总览，M-26 生长）。
///
/// 背景整圆轨道 + 前景弧，从顶部顺时针生长 [progress]，生长比例由 [grow] 控制
/// （0→1，动画由外层 StatefulWidget 驱动）。[grow]=1 即终态。纯绘制，不读 context。
class RingPainter extends CustomPainter {
  /// 创建正确率环画笔。
  const RingPainter({
    required this.progress,
    required this.grow,
    required this.trackColor,
    required this.arcColor,
    required this.stroke,
  });

  /// 目标正确率 [0, 1]。
  final double progress;

  /// 生长比例 [0, 1]。
  final double grow;

  /// 轨道色。
  final Color trackColor;

  /// 前景弧色。
  final Color arcColor;

  /// 线宽。
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
  bool shouldRepaint(covariant RingPainter old) =>
      old.progress != progress ||
      old.grow != grow ||
      old.trackColor != trackColor ||
      old.arcColor != arcColor ||
      old.stroke != stroke;
}
