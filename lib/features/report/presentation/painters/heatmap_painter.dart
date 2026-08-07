import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:interval_ear/core/utils/math_utils.dart';

/// 每日练习热力图画笔（报告）。
///
/// `values` 按时间升序（最旧→最新），每 [rows] 个为一列（周），行=星期。
/// 颜色在 [emptyColor]→[baseColor] 间按强度插值。纯绘制，颜色由构造传入。
class HeatmapPainter extends CustomPainter {
  /// 创建热力图画笔。
  HeatmapPainter({
    required this.values,
    required this.rows,
    required this.grow,
    required this.baseColor,
    required this.emptyColor,
    required this.gap,
  });

  /// 各日强度 [0, 1]，按时间升序。
  final List<double> values;

  /// 每列行数（星期数，通常 7）。
  final int rows;

  /// 揭示比例 [0, 1]。
  final double grow;

  /// 高强度底色。
  final Color baseColor;

  /// 零强度底色。
  final Color emptyColor;

  /// 单元格间距。
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = values.length;
    if (n == 0 || rows <= 0) {
      return;
    }
    final int columns = (n / rows).ceil();
    final double cell = math.min(
      (size.width - gap * (columns + 1)) / columns,
      (size.height - gap * (rows + 1)) / rows,
    );
    final double startX =
        (size.width - (cell * columns + gap * (columns - 1))) / 2;
    final double startY = (size.height - (cell * rows + gap * (rows - 1))) / 2;

    for (int i = 0; i < n; i++) {
      final int col = i ~/ rows;
      final int row = i % rows;
      final double intensity =
          MathUtils.clampDouble(values[i], 0, 1) *
          MathUtils.clampDouble(grow, 0, 1);
      final double x = startX + col * (cell + gap);
      final double y = startY + row * (cell + gap);
      final Color color = Color.lerp(emptyColor, baseColor, intensity)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cell, cell),
          Radius.circular(math.min(3, cell / 3)),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter old) =>
      old.values != values ||
      old.rows != rows ||
      old.grow != grow ||
      old.baseColor != baseColor ||
      old.emptyColor != emptyColor ||
      old.gap != gap;
}
