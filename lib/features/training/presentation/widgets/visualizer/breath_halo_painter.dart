import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 光环呼吸可视化画笔（`M-08` viz.breathHalo）。
///
/// **纵深防御（防泄露）**：画笔只接收 `amplitude`（由 `EnvelopeSampler.amplitudeAt`
/// 纯函数按「距起音毫秒数」算出，与音高/音色无关）与 `phase`（环境呼吸相位），
/// **绝不**接收任何音高/频率。因此渲染结果在所有音程/音色下完全一致（§5.6 golden）。
class BreathHaloPainter extends CustomPainter {
  /// 创建光环画笔。
  const BreathHaloPainter({
    required this.amplitude,
    required this.phase,
    required this.color,
  });

  /// 当前可视化幅度 [0, 1]。
  final double amplitude;

  /// 呼吸循环相位 [0, 1]（`reduced`/`off` 档下固定为 0，停循环）。
  final double phase;

  /// 主色（来自语义色，非音程专属色）。
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final breath = 0.85 + 0.15 * (0.5 - 0.5 * math.cos(phase * 2 * math.pi));
    final baseScale = (0.35 + 0.5 * amplitude) * breath;

    for (var i = 0; i < 3; i++) {
      final t = i / 2;
      final radius = maxRadius * (baseScale - t * 0.18);
      if (radius <= 0) {
        continue;
      }
      final opacity = (0.5 - t * 0.15) * (0.4 + 0.6 * amplitude);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius, paint);
    }

    // 中心实心点，随幅度放大。
    final dotRadius = maxRadius * (0.12 + 0.22 * amplitude);
    final dotPaint = Paint()
      ..color = color.withValues(alpha: (0.5 + 0.5 * amplitude).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(BreathHaloPainter old) =>
      old.amplitude != amplitude || old.phase != phase || old.color != color;
}
