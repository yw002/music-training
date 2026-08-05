import 'dart:math' as math;
import 'dart:typed_data';

import 'package:interval_ear/core/audio/synth/envelope.dart';
import 'package:interval_ear/core/audio/synth/synth_constants.dart';
import 'package:interval_ear/features/training/domain/services/frequency_calculator.dart';

/// 合成键盘音色：5 次谐波叠加 + 弦不谐性微失谐 + 逐谐波指数衰减（架构 §5.5）。
///
/// 为什么「逐谐波各自的衰减速度」：真实钢琴高次谐波衰减比基频快，单一
/// `exp(-t/τ)` 会听起来像廉价电子琴。每个谐波带自己的 [kDecayTau]/[decay] 倍率。
///
/// **跨平台字节一致铁律②**：所有中间运算用 `double`（IEEE-754 双精度），累加在
/// `double` 寄存器里完成，禁止用 `Float32List` 做累加中转。最终样本才写入
/// `Float32List`。
class KeyboardVoice {
  KeyboardVoice._();

  /// 谐波表：(倍数 mult, 幅度 amp, 衰减倍率 decay)。
  ///
  /// 衰减时间常数实际为 `kDecayTau / decay`：decay 越大，该谐波衰减越快。
  static const List<(double mult, double amp, double decay)> kHarmonics =
      <(double, double, double)>[
    (1.0, 1.00, 1.00),
    (2.0, 0.42, 1.35),
    (3.0, 0.21, 1.70),
    (4.0, 0.11, 2.10),
    (5.0, 0.055, 2.60),
  ];

  /// 基频指数衰减时间常数（秒）。
  static const double kDecayTau = 0.55;

  /// 弦不谐系数（微失谐）：`fk = f0 · mult · sqrt(1 + β·k²)`。
  ///
  /// β=0.0004 让高次谐波频率略高于整数倍，模拟钢琴弦的刚度，音色更「真」。
  static const double kInharmonicity = 0.0004;

  /// 单音默认时长（秒），仅作独立调用兜底；实际序列渲染以 spec 时长为准。
  static const double kNoteDuration = 1.100;

  /// 起音淡入时长（毫秒），raised-cosine 防 click。
  static const double kAttackMs = 6;

  /// 收音淡出时长（毫秒），raised-cosine 防 click。
  static const double kReleaseMs = 40;

  /// 渲染单音 PCM（Float32List，范围约 [-kVoiceGain, kVoiceGain]）。
  ///
  /// [midi] MIDI 音高；[durationMs] 时长（毫秒）；[sampleRate] 采样率。
  static Float32List render(int midi, int durationMs, int sampleRate) {
    final double freq = FrequencyCalculator.midiToFrequency(midi);
    final int sampleCount = (durationMs * sampleRate / 1000).round();
    final Float32List out = Float32List(sampleCount);

    // 预计算每个谐波的频率与衰减率（仅开一次方），内层循环只做乘加。
    final int n = kHarmonics.length;
    final Float64List harmFreq = Float64List(n);
    final Float64List harmTau = Float64List(n);
    for (int h = 0; h < n; h++) {
      final (double mult, double amp, double decay) = kHarmonics[h];
      final int k = h + 1;
      harmFreq[h] = freq * mult * math.sqrt(1 + kInharmonicity * k * k);
      harmTau[h] = kDecayTau / decay;
    }

    for (int i = 0; i < sampleCount; i++) {
      final double t = i / sampleRate;
      // 累加在 double 寄存器里完成（铁律②）。
      double s = 0.0;
      for (int h = 0; h < n; h++) {
        final (double mult, double amp, double decay) = kHarmonics[h];
        s += amp * math.sin(2 * math.pi * harmFreq[h] * t) *
            math.exp(-t / harmTau[h]);
      }
      final double env = RaisedCosineEnvelope.value(
        index: i,
        sampleCount: sampleCount,
        attackMs: kAttackMs,
        releaseMs: kReleaseMs,
        sampleRate: sampleRate,
      );
      out[i] = s * env * SynthConstants.kVoiceGain;
    }
    return out;
  }
}
