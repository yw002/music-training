import 'package:flutter/material.dart';

/// 半音尺画笔（`M-18` compare.semitoneRuler）。
///
/// 画一条半音刻度轴，并在正确音程 / 用户所选音程对应的半音位置画两根竖条
/// （正确向上、所选向下）。`progress` [0,1] 控制竖条生长入场（`reduced`/`off` 档下
/// 由 widget 把时长折成「直接到终态」）。这是**教学信息**，不涉及任何音高泄露。
class SemitoneRulerPainter extends CustomPainter {
  /// 创建半音尺画笔。
  const SemitoneRulerPainter({
    required this.correctSemitones,
    required this.selectedSemitones,
    required this.correctColor,
    required this.selectedColor,
    required this.progress,
    required this.maxSemitones,
  });

  /// 正确音程半音数。
  final int correctSemitones;

  /// 用户所选音程半音数。
  final int selectedSemitones;

  /// 正确色。
  final Color correctColor;

  /// 所选色。
  final Color selectedColor;

  /// 入场进度 [0, 1]。
  final double progress;

  /// 半音数上界（纯八度 12）。
  final int maxSemitones;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 16.0;
    const left = pad;
    final right = size.width - pad;
    final axisY = size.height / 2;
    final step = (right - left) / maxSemitones;

    // 刻度轴。
    final axisPaint = Paint()
      ..color = const Color(0x33999999)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, axisY), Offset(right, axisY), axisPaint);
    for (var i = 0; i <= maxSemitones; i++) {
      final x = left + step * i;
      canvas.drawLine(
        Offset(x, axisY - 4),
        Offset(x, axisY + 4),
        axisPaint,
      );
    }

    final upHeight = (size.height / 2 - 8) * progress;
    final downHeight = (size.height / 2 - 8) * progress;

    // 正确音程（向上）。
    final correctX = left + step * correctSemitones;
    final correctPaint = Paint()
      ..color = correctColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(correctX, axisY),
      Offset(correctX, axisY - upHeight),
      correctPaint,
    );

    // 所选音程（向下）。
    final selectedX = left + step * selectedSemitones;
    final selectedPaint = Paint()
      ..color = selectedColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(selectedX, axisY),
      Offset(selectedX, axisY + downHeight),
      selectedPaint,
    );
  }

  @override
  bool shouldRepaint(SemitoneRulerPainter old) =>
      old.correctSemitones != correctSemitones ||
      old.selectedSemitones != selectedSemitones ||
      old.correctColor != correctColor ||
      old.selectedColor != selectedColor ||
      old.progress != progress ||
      old.maxSemitones != maxSemitones;
}
