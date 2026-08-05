import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/synth/normalizer.dart';

/// T07 验收 1/4 + 任务清单：峰值归一到 0.82、和声混音不削顶。
double _peak(Float32List x) {
  double p = 0.0;
  for (final double s in x) {
    final double a = s.abs();
    if (a > p) p = a;
  }
  return p;
}

void main() {
  group('Normalizer.normalize 峰值归一', () {
    test('会削波的信号被压到 kPeakTarget=0.82', () {
      final Float32List x = Float32List.fromList(<double>[
        for (int i = 0; i < 1000; i++) math.sin(i * 0.1) * 0.95,
      ]);
      // 离散采样下正弦峰值略低于 0.95，只需确认它确实会削波（>0.82）即可。
      expect(_peak(x), greaterThan(0.9));
      Normalizer.normalize(x);
      expect(_peak(x), closeTo(Normalizer.kPeakTarget, 1e-6));
    });

    test('安静信号（峰值 < 0.82）只衰减不放大——铁律', () {
      final Float32List x = Float32List.fromList(<double>[
        for (int i = 0; i < 1000; i++) math.sin(i * 0.1) * 0.4,
      ]);
      final Float32List before = Float32List.fromList(x);
      Normalizer.normalize(x);
      for (int i = 0; i < x.length; i++) {
        expect(x[i], before[i]); // 完全不变（g>1 不应用）。
      }
    });

    test('恰好 0.82 的信号保持不变', () {
      final Float32List x = Float32List.fromList(<double>[
        for (int i = 0; i < 1000; i++) math.sin(i * 0.1) * 0.82,
      ]);
      final Float32List before = Float32List.fromList(x);
      Normalizer.normalize(x);
      for (int i = 0; i < x.length; i++) {
        expect(x[i], before[i]);
      }
    });

    test('全零信号不崩溃', () {
      final Float32List x = Float32List(100);
      Normalizer.normalize(x);
      expect(_peak(x), 0.0);
    });
  });

  group('Normalizer.softLimit 软限幅', () {
    test('|x| ≤ 0.95 直通', () {
      for (double x = -0.9; x <= 0.9; x += 0.05) {
        expect(Normalizer.softLimit(x), closeTo(x, 1e-12));
      }
    });

    test('超量部分被平滑压到约 1，绝不硬削顶（|softLimit| ≤ 1）', () {
      for (double x = 0.95; x <= 3.0; x += 0.1) {
        final double y = Normalizer.softLimit(x);
        expect(y, greaterThanOrEqualTo(0.95));
        expect(y, lessThanOrEqualTo(1.0)); // 不削顶：永不超过 1（渐近逼近 1）。
        expect(y.abs(), closeTo(1.0, 0.06));
      }
      for (double x = -3.0; x <= -0.95; x += 0.1) {
        final double y = Normalizer.softLimit(x);
        expect(y, lessThanOrEqualTo(-0.95));
        expect(y, greaterThanOrEqualTo(-1.0));
        expect(y.abs(), closeTo(1.0, 0.06));
      }
    });
  });

  group('Normalizer 和声混音不削顶（T07 验收 4 关联）', () {
    test('两路大声信号相加后逐样本软限幅，无样本触顶 ±1', () {
      final Float32List a = Float32List.fromList(<double>[
        for (int i = 0; i < 2000; i++) math.sin(i * 0.07) * 0.9,
      ]);
      final Float32List b = Float32List.fromList(<double>[
        for (int i = 0; i < 2000; i++) math.cos(i * 0.05) * 0.9,
      ]);
      final Float32List mixed = Float32List(a.length);
      for (int i = 0; i < a.length; i++) {
        mixed[i] = Normalizer.softLimit(a[i] + b[i]);
      }
      final double peak = _peak(mixed);
      // 软限幅后峰值 ≤ 1.0（不硬削顶、不超限），且确被压缩到接近 1。
      expect(peak, lessThanOrEqualTo(1.0));
      expect(peak, greaterThan(0.95));
    });
  });
}
