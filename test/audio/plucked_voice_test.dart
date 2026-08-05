import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/synth/plucked_voice.dart';
import 'package:interval_ear/features/training/domain/services/frequency_calculator.dart';

/// T07 验收 1/2 + 任务清单：拨弦音色的长度、峰值 ≤1、起止无爆音、确定性，
/// 以及基频估计落在 ±2%。
///
/// 基频估计改用**自相关**（而非过零率）：Karplus–Strong 拨弦含丰富谐波，过零率
/// 会被高次谐波主导而严重高估（实测偏差 >700%）。自相关在「期望周期附近窗口」内
/// 搜索峰值并做抛物线插值，稳定且对谐波鲁棒。
double _autocorrPitch(Float32List x, int sr, double expectedFreq) {
  final int n = x.length;
  final int winLen = math.min(8192, n - 400);
  final int winStart = ((n - winLen) / 2).round();
  final double pExp = sr / expectedFreq;
  int lo = (pExp * 0.5).round();
  int hi = (pExp * 1.5).round();
  if (lo < 2) lo = 2;
  if (hi >= winLen) hi = winLen - 1;
  if (hi <= lo) hi = lo + 1;

  // Hann 窗降边界效应；按 (winLen - tau) 归一化去偏，凸显基频峰。
  final Float32List buf = Float32List(winLen);
  for (int i = 0; i < winLen; i++) {
    final double w = 0.5 - 0.5 * math.cos(2 * math.pi * i / (winLen - 1));
    buf[i] = x[winStart + i] * w;
  }
  double bestR = double.negativeInfinity;
  int bestTau = lo;
  for (int tau = lo; tau <= hi; tau++) {
    double r = 0.0;
    for (int i = 0; i < winLen - tau; i++) {
      r += buf[i] * buf[i + tau];
    }
    r /= winLen - tau;
    if (r > bestR) {
      bestR = r;
      bestTau = tau;
    }
  }
  final int t0 = bestTau;
  final double rPrev = (t0 - 1 >= lo) ? _acNorm(buf, t0 - 1) : bestR;
  final double rNext = (t0 + 1 <= hi) ? _acNorm(buf, t0 + 1) : bestR;
  final double denom = rPrev - 2 * bestR + rNext;
  final double delta =
      denom.abs() < 1e-12 ? 0.0 : 0.5 * (rPrev - rNext) / denom;
  return sr / (t0 + delta);
}

double _acNorm(Float32List buf, int tau) {
  double r = 0.0;
  for (int i = 0; i < buf.length - tau; i++) {
    r += buf[i] * buf[i + tau];
  }
  return r / (buf.length - tau);
}

void main() {
  const int sr = 44100;

  group('PluckedVoice 基本几何与防 click', () {
    test('渲染长度 = round(durationMs * sr / 1000)', () {
      final Float32List a = PluckedVoice.render(60, 1100, sr);
      expect(a.length, (1100 * sr / 1000).round());
    });

    test('峰值 ≤ 1（无削波）', () {
      double peak = 0.0;
      final Float32List a = PluckedVoice.render(60, 1100, sr);
      for (final double s in a) {
        peak = math.max(peak, s.abs());
      }
      expect(peak, lessThanOrEqualTo(1.0));
      expect(peak, lessThan(0.5));
    });

    test('T07 验收 1·起止无爆音：首样本 ≈ 0、尾样本 ≈ 0', () {
      final Float32List a = PluckedVoice.render(64, 1100, sr);
      // 拨弦为噪声激励起音，若未加淡入淡出包络则首样本为满量程噪声 → click。
      expect(a.first.abs(), lessThan(1e-3),
          reason: '首样本应≈0（无起音爆音）');
      expect(a.last.abs(), lessThan(1e-2),
          reason: '尾样本应≈0（无释放爆音）');
    });

    test('loopPeriodSamples 与 midiToHz 反算一致', () {
      for (final int midi in <int>[48, 60, 72, 84]) {
        final double f = FrequencyCalculator.midiToFrequency(midi);
        final double period = PluckedVoice.loopPeriodSamples(midi, sr);
        expect(period, closeTo(sr / f, 1e-9));
      }
    });
  });

  group('PluckedVoice 确定性（T07 验收 2）', () {
    test('同参数两次渲染逐样本完全一致（Xorshift32Random seed:N）', () {
      final Float32List a = PluckedVoice.render(60, 1100, sr);
      final Float32List b = PluckedVoice.render(60, 1100, sr);
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(a[i], b[i], reason: '样本 $i 不一致');
      }
    });

    test('改变 midi 改变输出', () {
      final Float32List a = PluckedVoice.render(60, 800, sr);
      final Float32List b = PluckedVoice.render(67, 800, sr);
      expect(a, isNot(equals(b)));
    });
  });

  group('PluckedVoice 基频估计（自相关，±2%）', () {
    test('中部窗口自相关估计基频与 midiToHz 偏差 < 2%', () {
      for (final int midi in <int>[48, 55, 60, 67, 72, 79, 84]) {
        final Float32List x = PluckedVoice.render(midi, 1100, sr);
        final double expected = FrequencyCalculator.midiToFrequency(midi);
        final double est = _autocorrPitch(x, sr, expected);
        final double err = (est - expected).abs() / expected;
        expect(err, lessThan(0.02),
            reason: 'MIDI=$midi 自相关估计 $est Hz 与期望 $expected Hz 偏差 '
                '${(err * 100).toStringAsFixed(2)}% 超 ±2%');
      }
    });
  });
}
