import 'package:flutter/material.dart';

/// 频谱粒子可视化画笔（`M-09` viz.spectrumParticles）。
///
/// 粒子数量受双重约束：[MotionParticleSpec.limitFor]（看门狗降级 48→16）+ 当前
/// [MotionScopeData.particleLimit]（reduced/off 归零）。粒子纵向偏移只由
/// `amplitude`（与音高无关）驱动，保证防泄露。
class SpectrumParticlesPainter extends CustomPainter {
  /// 创建粒子画笔。
  const SpectrumParticlesPainter({
    required this.amplitude,
    required this.color,
    required this.particleCount,
    required this.seed,
  });

  /// 当前可视化幅度 [0, 1]。
  final double amplitude;

  /// 主色（语义色，非音程专属色）。
  final Color color;

  /// 当前允许的粒子数（已受双重约束）。
  final int particleCount;

  /// 随机种子（仅影响粒子横向分布，与音高无关）。
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (particleCount <= 0) {
      return;
    }
    final random = _SeededRandom(seed);
    final barWidth = size.width / particleCount;
    for (var i = 0; i < particleCount; i++) {
      final centerX = (i + 0.5) * barWidth;
      final variance = 0.6 + 0.4 * random.next();
      final barHeight = size.height * amplitude * variance;
      final radius = (barWidth * 0.4).clamp(1.0, 8.0);
      final y = size.height - barHeight;
      final paint = Paint()
        ..color = color.withValues(alpha: (0.35 + 0.65 * amplitude).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - radius, y, radius * 2, barHeight),
          Radius.circular(radius),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SpectrumParticlesPainter old) =>
      old.amplitude != amplitude ||
      old.color != color ||
      old.particleCount != particleCount ||
      old.seed != seed;
}

/// 轻量可复现伪随机（仅用于粒子布局，不引入音高相关性）。
class _SeededRandom {
  _SeededRandom(this._state);

  int _state;

  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}
