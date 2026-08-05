import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/synth/pcm_synthesizer.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/services/frequency_calculator.dart';

/// T07 验收 2/3/4 + 任务清单：
/// - renderNote 确定性（同参数逐字节一致）；
/// - 音高准确度：C3–C6 共 37 个 MIDI，自相关估计基频与 midiToHz 偏差 < 5 音分；
/// - 响度一致：13 音程同根音下 RMS 极差 < 3 dB。
///
/// 自相关基频估计：在「期望周期附近的窗口」内搜索归一化自相关峰值（避开八度误判），
/// 再做抛物线插值取亚样本精度。窗口以 midiToHz 反算周期为基准，仅用于排除八度误差，
/// 不限制偏差大小，故仍真实反映音高准确度。Hann 窗 + 按 (N-τ) 归一化可凸显基频峰，
/// 提高低频（长周期）估计精度（避免把 5 音分边缘的偏差误判为源码缺陷）。
double _autocorrPitch(
  Float32List x,
  int sr,
  double expectedFreq,
) {
  final int n = x.length;
  final int winLen = math.min(8192, n - 400);
  final int winStart = ((n - winLen) / 2).round();
  final double pExp = sr / expectedFreq;
  int lo = (pExp * 0.5).round();
  int hi = (pExp * 1.5).round();
  if (lo < 2) lo = 2;
  if (hi >= winLen) hi = winLen - 1;
  if (hi <= lo) hi = lo + 1;

  // Hann 窗降边界效应。
  final Float32List buf = Float32List(winLen);
  for (int i = 0; i < winLen; i++) {
    final double w = 0.5 - 0.5 * math.cos(2 * math.pi * i / (winLen - 1));
    buf[i] = x[winStart + i] * w;
  }

  double bestR = double.negativeInfinity;
  int bestTau = lo;
  for (int tau = lo; tau <= hi; tau++) {
    final double r = _acNorm(buf, tau);
    if (r > bestR) {
      bestR = r;
      bestTau = tau;
    }
  }
  // 抛物线插值取亚样本峰值位置。
  final int t0 = bestTau;
  final double rPrev = (t0 - 1 >= lo) ? _acNorm(buf, t0 - 1) : bestR;
  final double rNext = (t0 + 1 <= hi) ? _acNorm(buf, t0 + 1) : bestR;
  final double denom = rPrev - 2 * bestR + rNext;
  final double delta =
      denom.abs() < 1e-12 ? 0.0 : 0.5 * (rPrev - rNext) / denom;
  final double tauEst = (t0 + delta).toDouble();
  return sr / tauEst;
}

double _acNorm(Float32List buf, int tau) {
  double r = 0.0;
  for (int i = 0; i < buf.length - tau; i++) {
    r += buf[i] * buf[i + tau];
  }
  return r / (buf.length - tau);
}

double _rms(Float32List x) {
  double sum = 0.0;
  for (final double s in x) {
    sum += s * s;
  }
  return math.sqrt(sum / x.length);
}

void main() {
  const int sr = 44100;

  group('PcmSynthesizer.renderNote 确定性（T07 验收 2）', () {
    for (final Timbre timbre in Timbre.values) {
      test('$timbre：同参数两次渲染逐字节一致', () {
        final Float32List a =
            PcmSynthesizer.renderNote(60, timbre, 800, sr);
        final Float32List b =
            PcmSynthesizer.renderNote(60, timbre, 800, sr);
        expect(a.length, b.length);
        for (int i = 0; i < a.length; i++) {
          expect(a[i], b[i], reason: '样本 $i 不一致');
        }
      });
    }
  });

  group('PcmSynthesizer 音高准确度（T07 验收 3：< 5 音分）', () {
    for (final Timbre timbre in Timbre.values) {
      test('$timbre：C3–C6 共 37 个 MIDI 自相关基频偏差 < 5 音分', () {
        for (int midi = 48; midi <= 84; midi++) {
          final Float32List x =
              PcmSynthesizer.renderNote(midi, timbre, 350, sr);
          final double expected = FrequencyCalculator.midiToFrequency(midi);
          final double est = _autocorrPitch(x, sr, expected);
          final double cents =
              1200 * math.log(est / expected) / math.ln2;
          expect(cents.abs(), lessThan(5.0),
              reason: '$timbre MIDI=$midi 估计 $est Hz 期望 $expected Hz '
                  '偏差 ${cents.toStringAsFixed(2)} 音分超 5');
        }
      });
    }
  });

  group('PcmSynthesizer 响度一致（T07 验收 4：13 音程 RMS 极差 < 3 dB）', () {
    for (final Timbre timbre in Timbre.values) {
      test('$timbre：同根音 C4 上 13 个音程 RMS 极差 < 3 dB', () {
        const int root = 60;
        final List<double> rmss = <double>[];
        for (final IntervalId id in IntervalId.values) {
          final int target = root + id.semitones;
          final Float32List x =
              PcmSynthesizer.renderNote(target, timbre, 1100, sr);
          rmss.add(_rms(x));
        }
        final double maxRms = rmss.reduce(math.max);
        final double minRms = rmss.reduce(math.min);
        final double rangeDb = 20 * math.log(maxRms / minRms) / math.ln10;
        expect(rangeDb, lessThan(3.0),
            reason: '$timbre 13 音程 RMS 极差 ${rangeDb.toStringAsFixed(2)} dB '
                '超 3 dB（min=$minRms, max=$maxRms）');
      });
    }
  });
}
