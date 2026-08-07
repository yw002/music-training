import 'package:flutter/material.dart';

import 'package:interval_ear/core/utils/math_utils.dart';

/// 13 音程正确率柱状图画笔（报告，M-26 生长）。
///
/// 每根柱子独立生长（[barProgress] 控制，支持交错入场）；柱子按音程标识色着色。
/// 纯绘制，颜色/线宽由构造传入，不在 painter 内读 context。
class BarChartPainter extends CustomPainter {
  /// 创建柱状图画笔。
  BarChartPainter({
    required this.values,
    required this.labels,
    required this.barColors,
    required this.barProgress,
    required this.trackColor,
    required this.axisColor,
    required this.labelColor,
    required this.gridColor,
    this.maxValue = 1,
  });

  /// 各柱正确率 [0, 1]，长度与 [labels]/[barColors] 一致。
  final List<double> values;

  /// x 轴短代号。
  final List<String> labels;

  /// 各柱颜色（音程标识色）。
  final List<Color> barColors;

  /// 各柱生长比例 [0, 1]（交错入场用）。
  final List<double> barProgress;

  /// 网格/轨道底色。
  final Color trackColor;

  /// 基线色。
  final Color axisColor;

  /// 标签色。
  final Color labelColor;

  /// 网格线色。
  final Color gridColor;

  /// 量程上限（默认 1）。
  final double maxValue;

  static const double _left = 8;
  static const double _right = 8;
  static const double _top = 22;
  static const double _bottom = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = values.length;
    if (n == 0) {
      return;
    }
    final double plotLeft = _left;
    final double plotRight = size.width - _right;
    final double plotTop = _top;
    final double plotBottom = size.height - _bottom;
    final double plotW = plotRight - plotLeft;
    final double plotH = plotBottom - plotTop;
    final double max = maxValue <= 0 ? 1 : maxValue;

    // 横向网格线（0.25/0.5/0.75/1.0）+ 基线。
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int g = 1; g <= 4; g++) {
      final double y = plotBottom - plotH * (g / 4);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
    }
    canvas.drawLine(
      Offset(plotLeft, plotBottom),
      Offset(plotRight, plotBottom),
      Paint()
        ..color = axisColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final double slot = plotW / n;
    final double barW = slot * 0.62;
    final TextStyle labelStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    final TextStyle valueStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    for (int i = 0; i < n; i++) {
      final double v = MathUtils.clampDouble(values[i], 0, max) / max;
      final double prog = MathUtils.clampDouble(barProgress[i], 0, 1);
      final double cx = plotLeft + slot * (i + 0.5);
      final double h = plotH * v * prog;
      final double top = plotBottom - h;
      if (h > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barW / 2, top, barW, h),
            const Radius.circular(4),
          ),
          Paint()..color = barColors[i],
        );
      }
      // 数值：接近终态时显示，避免生长过程中抖动。
      if (v > 0 && prog > 0.92) {
        _drawText(
          canvas,
          MathUtils.toPercent(values[i]).toString(),
          Offset(cx, top - 8),
          valueStyle,
        );
      }
      // x 轴短代号。
      _drawText(canvas, labels[i], Offset(cx, plotBottom + 8), labelStyle);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, TextStyle style) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant BarChartPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.barColors != barColors ||
      old.barProgress != barProgress ||
      old.trackColor != trackColor ||
      old.axisColor != axisColor ||
      old.labelColor != labelColor ||
      old.gridColor != gridColor ||
      old.maxValue != maxValue;
}
