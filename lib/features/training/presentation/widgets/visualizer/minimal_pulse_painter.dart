import 'package:flutter/material.dart';

/// 极简脉冲可视化画笔（`M-10` viz.minimal）。
///
/// 最省性能的降级方案（看门狗三级降级后的强制方案）：只有一个随幅度缩放的实心
/// 圆点。**不读取音高/频率**，幅度仍只来自 `EnvelopeSampler.amplitudeAt`。
class MinimalPulsePainter extends CustomPainter {
  /// 创建极简脉冲画笔。
  const MinimalPulsePainter({
    required this.amplitude,
    required this.color,
  });

  /// 当前可视化幅度 [0, 1]。
  final double amplitude;

  /// 主色（语义色）。
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final radius = maxRadius * (0.25 + 0.6 * amplitude);
    final paint = Paint()
      ..color = color.withValues(alpha: (0.4 + 0.6 * amplitude).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(MinimalPulsePainter old) =>
      old.amplitude != amplitude || old.color != color;
}
