import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// 答对庆祝粒子系统（架构 §3.10 / T14）。
///
/// 双重约束（粒子数受 [CelebrationLevel] + [MotionGovernor] 限制）：
/// 1. `reduced`/`off` 档下 `context.allowParticles` 为 `false` → 完全不渲染；
/// 2. 看门狗降级（[MotionDegradeStage.reducesParticles]）把上限从 48 压到 16；
/// 3. [CelebrationLevel.off] 时调用方应传入 `count=0`。
///
/// 使用**对象池**复用粒子对象，避免高频庆祝下的 GC 抖动：活跃粒子回收后存入
/// `_pool`，下次 burst 直接取出重置，而非反复 new/dispose。
class ParticleSystem extends StatefulWidget {
  /// 创建粒子系统。
  const ParticleSystem({
    required this.burstKey,
    required this.count,
    required this.color,
    this.maxParticles = 48,
    super.key,
  });

  /// 自增触发键：变化时发射一波粒子。
  final int burstKey;

  /// 本波粒子数（已由调用方按庆祝强度折算）。
  final int count;

  /// 粒子颜色。
  final Color color;

  /// 粒子数硬上限（看门狗降级前的 48）。
  final int maxParticles;

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _Particle {
  _Particle({required this.lifeMs});
  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
  double ageMs = 0;
  final double lifeMs;
}

class _ParticleSystemState extends State<ParticleSystem>
    with SingleTickerProviderStateMixin {
  final math.Random _random = math.Random();
  final List<_Particle> _pool = <_Particle>[];
  final List<_Particle> _active = <_Particle>[];
  late Ticker _ticker;
  int _lastKey = 0;
  late Duration _lastElapsed;

  @override
  void initState() {
    super.initState();
    _lastKey = widget.burstKey;
    _lastElapsed = Duration.zero;
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(ParticleSystem old) {
    super.didUpdateWidget(old);
    if (widget.burstKey != _lastKey) {
      _lastKey = widget.burstKey;
      _burst(widget.count);
    }
  }

  int _effectiveMax() {
    final data = MotionScope.of(context);
    if (!data.allowParticles) {
      return 0;
    }
    final spec = AppMotionTokens.standard().viz.spectrumParticles;
    return data.stage.reducesParticles ? spec.degradedMaxParticles : spec.maxParticles;
  }

  void _burst(int requested) {
    if (!MotionScope.of(context).allowParticles) {
      return;
    }
    final max = _effectiveMax();
    final n = requested.clamp(0, max);
    for (var i = 0; i < n; i++) {
      final particle = _pool.isNotEmpty
          ? _pool.removeLast()
          : _Particle(lifeMs: 700);
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 40 + _random.nextDouble() * 80;
      particle.position = Offset.zero;
      particle.velocity = Offset(math.cos(angle) * speed, math.sin(angle) * speed - 40);
      particle.ageMs = 0;
      _active.add(particle);
    }
  }

  void _tick(Duration elapsed) {
    if (_active.isEmpty) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    final dtMs = dt.inMilliseconds.toDouble();
    for (final p in _active) {
      p.ageMs += dtMs;
      p.position += p.velocity * (dtMs / 1000);
      p.velocity += const Offset(0, 120) * (dtMs / 1000); // 轻微重力。
    }
    _active.removeWhere((p) {
      if (p.ageMs >= p.lifeMs) {
        if (_pool.length < widget.maxParticles) {
          _pool.add(p);
        }
        return true;
      }
      return false;
    });
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MotionScope.of(context).allowParticles || _active.isEmpty) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: _ParticlePainter(
        particles: _active,
        color: widget.color,
      ),
      size: Size.infinite,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.particles, required this.color});

  final List<_Particle> particles;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final t = (p.ageMs / p.lifeMs).clamp(0.0, 1.0);
      final opacity = (1 - t).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: opacity * 0.9);
      final radius = (3 + 3 * (1 - t)).clamp(1.0, 8.0);
      canvas.drawCircle(center + p.position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}
