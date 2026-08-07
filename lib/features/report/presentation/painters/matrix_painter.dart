import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:interval_ear/core/utils/math_utils.dart';

/// 混淆矩阵画笔（报告，M-27 波次揭示 260/22/900）。
///
/// `counts[row][col]`：行=实际音程，列=所选音程；对角线=答对（success 色），
/// 非对角=混淆（warning 色），强度按 `count/maxCount`。`reveal` 控制沿 r+c
/// 对角线的波次揭示（0→1 终态）。零格留白（仅极淡结构色），符合「稀疏留白」。
/// 纯绘制，颜色由构造传入，不在 painter 内读 context。
class MatrixPainter extends CustomPainter {
  /// 创建混淆矩阵画笔。
  MatrixPainter({
    required this.counts,
    required this.reveal,
    required this.maxCount,
    required this.diagonalColor,
    required this.offColor,
    required this.textColor,
    required this.gridColor,
    required this.emptyColor,
    required this.rowLabels,
    required this.columnLabels,
  });

  /// 计数矩阵，[counts][row=actual][col=selected]。
  final List<List<int>> counts;

  /// 波次揭示比例 [0, 1]。
  final double reveal;

  /// 最大格值（用于归一化，<=0 时按 1 处理）。
  final int maxCount;

  /// 对角线（答对）色。
  final Color diagonalColor;

  /// 非对角（混淆）色。
  final Color offColor;

  /// 文本色。
  final Color textColor;

  /// 网格结构色（实际未使用填充，保留扩展）。
  final Color gridColor;

  /// 零格极淡结构色。
  final Color emptyColor;

  /// 行标签（实际音程短代号）。
  final List<String> rowLabels;

  /// 列标签（所选音程短代号）。
  final List<String> columnLabels;

  static const double _labelLeft = 26;
  static const double _labelTop = 22;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = counts.length;
    if (n == 0) {
      return;
    }
    final double gridLeft = _labelLeft;
    final double gridTop = _labelTop;
    final double gridW = size.width - gridLeft - 6;
    final double gridH = size.height - gridTop - 6;
    final double cell = math.min(gridW, gridH) / n;
    final double originX = gridLeft + (gridW - cell * n) / 2;
    final double originY = gridTop + (gridH - cell * n) / 2;
    final double norm = maxCount <= 0 ? 1 : maxCount.toDouble();
    final int totalWave = 2 * (n - 1);

    final TextStyle labelStyle = TextStyle(color: textColor, fontSize: 9);
    final TextStyle cellStyle = TextStyle(
      color: textColor,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    // 列标签（顶部）。
    for (int c = 0; c < n; c++) {
      final double cx = originX + cell * (c + 0.5);
      _drawText(canvas, columnLabels[c], Offset(cx, gridTop - 4), labelStyle);
    }
    // 行标签（左侧）。
    for (int r = 0; r < n; r++) {
      final double cy = originY + cell * (r + 0.5);
      _drawText(
        canvas,
        rowLabels[r],
        Offset(gridLeft - 4, cy),
        labelStyle,
        align: TextAlign.right,
      );
    }

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final double x = originX + cell * c;
        final double y = originY + cell * r;
        final int count = counts[r][c];
        // 沿 r+c 对角线推进的波次揭示。
        final double cellReveal = MathUtils.clampDouble(
          (reveal * totalWave - (r + c)) / 1.0,
          0,
          1,
        );
        if (cellReveal <= 0) {
          continue;
        }
        final Rect rect = Rect.fromLTWH(
          x + _gap / 2,
          y + _gap / 2,
          cell - _gap,
          cell - _gap,
        );
        if (count <= 0) {
          // 稀疏留白：零格仅极淡结构填充。
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(3)),
            Paint()..color = emptyColor,
          );
          continue;
        }
        final double intensity = MathUtils.clampDouble(count / norm, 0, 1);
        final Color base = r == c ? diagonalColor : offColor;
        final double alpha = MathUtils.lerp(0.35, 1.0, intensity) * cellReveal;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = base.withValues(alpha: alpha),
        );
        if (cellReveal > 0.6) {
          _drawText(
            canvas,
            count.toString(),
            Offset(rect.center.dx, rect.center.dy),
            cellStyle,
          );
        }
      }
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
  bool shouldRepaint(covariant MatrixPainter old) =>
      old.counts != counts ||
      old.reveal != reveal ||
      old.maxCount != maxCount ||
      old.diagonalColor != diagonalColor ||
      old.offColor != offColor ||
      old.textColor != textColor ||
      old.gridColor != gridColor ||
      old.emptyColor != emptyColor ||
      old.rowLabels != rowLabels ||
      old.columnLabels != columnLabels;
}
