import 'package:flutter/material.dart';

import 'package:interval_ear/core/utils/math_utils.dart';

/// 趋势折线图画笔（报告，M-26 描边 800ms）。
///
/// [grow] 控制折线从最旧点向最新点「画出来」的比例 [0,1]。纯绘制，颜色由构造传入，
/// 不在 painter 内读 context。
class LineChartPainter extends CustomPainter {
  /// 创建折线图画笔。
  LineChartPainter({
    required this.values,
    required this.labels,
    required this.grow,
    required this.lineColor,
    required this.areaColor,
    required this.gridColor,
    required this.axisColor,
    required this.labelColor,
    this.maxValue = 1,
  });

  /// 各点正确率 [0, 1]，按时间升序。
  final List<double> values;

  /// x 轴标签（首尾 + 中点）。
  final List<String> labels;

  /// 折线描出比例 [0, 1]。
  final double grow;

  /// 折线色。
  final Color lineColor;

  /// 面积填充色。
  final Color areaColor;

  /// 网格线色。
  final Color gridColor;

  /// 基线色。
  final Color axisColor;

  /// 标签色。
  final Color labelColor;

  /// 量程上限（默认 1）。
  final double maxValue;

  static const double _left = 30;
  static const double _right = 8;
  static const double _top = 16;
  static const double _bottom = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = values.length;
    if (n < 2) {
      return;
    }
    final double plotLeft = _left;
    final double plotRight = size.width - _right;
    final double plotTop = _top;
    final double plotBottom = size.height - _bottom;
    final double plotW = plotRight - plotLeft;
    final double plotH = plotBottom - plotTop;
    final double max = maxValue <= 0 ? 1 : maxValue;

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final TextStyle labelStyle = TextStyle(color: labelColor, fontSize: 9);

    // 横向网格线 + y 轴标签。
    for (int g = 0; g <= 4; g++) {
      final double frac = g / 4;
      final double y = plotBottom - plotH * frac;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      _drawText(
        canvas,
        MathUtils.toPercent(frac * max).toString(),
        Offset(plotLeft - 6, y),
        labelStyle,
        align: TextAlign.right,
      );
    }

    final List<Offset> pts = <Offset>[
      for (int i = 0; i < n; i++)
        Offset(
          plotLeft + plotW * (i / (n - 1)),
          plotBottom - plotH * (MathUtils.clampDouble(values[i], 0, max) / max),
        ),
    ];

    final double reveal = MathUtils.clampDouble(grow, 0, 1);
    final double total = (n - 1) * reveal;
    final int full = total.floor();
    final double frac = total - full;

    // 已完全画出的点（含部分段终点）。
    final List<Offset> drawn = <Offset>[pts[0]];
    for (int i = 1; i <= full && i < n; i++) {
      drawn.add(pts[i]);
    }
    if (full < n - 1) {
      final Offset a = pts[full];
      final Offset b = pts[full + 1];
      drawn.add(Offset(
        MathUtils.lerp(a.dx, b.dx, frac),
        MathUtils.lerp(a.dy, b.dy, frac),
      ));
    }

    // 面积填充。
    if (drawn.length >= 2) {
      final Path area = Path()
        ..moveTo(drawn.first.dx, plotBottom)
        ..lineTo(drawn.first.dx, drawn.first.dy);
      for (int i = 1; i < drawn.length; i++) {
        area.lineTo(drawn[i].dx, drawn[i].dy);
      }
      area.lineTo(drawn.last.dx, plotBottom);
      area.close();
      canvas.drawPath(area, Paint()..color = areaColor);
    }

    // 折线。
    if (drawn.length >= 2) {
      final Path line = Path()..moveTo(drawn.first.dx, drawn.first.dy);
      for (int i = 1; i < drawn.length; i++) {
        line.lineTo(drawn[i].dx, drawn[i].dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 数据点。
    for (final Offset p in drawn) {
      canvas.drawCircle(p, 3, Paint()..color = lineColor);
    }

    // x 轴标签：首尾 + 中点，避免拥挤。
    _drawText(canvas, labels.first, Offset(plotLeft, plotBottom + 8), labelStyle);
    _drawText(
      canvas,
      labels.last,
      Offset(plotRight, plotBottom + 8),
      labelStyle,
      align: TextAlign.right,
    );
    if (labels.length > 2) {
      _drawText(
        canvas,
        labels[labels.length ~/ 2],
        Offset((plotLeft + plotRight) / 2, plotBottom + 8),
        labelStyle,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style, {
    TextAlign align = TextAlign.center,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final double dx =
        align == TextAlign.right ? center.dx - tp.width : center.dx - tp.width / 2;
    tp.paint(canvas, Offset(dx, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant LineChartPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.grow != grow ||
      old.lineColor != lineColor ||
      old.areaColor != areaColor ||
      old.gridColor != gridColor ||
      old.axisColor != axisColor ||
      old.labelColor != labelColor ||
      old.maxValue != maxValue;
}
