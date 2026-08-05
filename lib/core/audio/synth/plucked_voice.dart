import 'dart:math' as math;
import 'dart:typed_data';

import 'package:interval_ear/core/audio/synth/envelope.dart';
import 'package:interval_ear/core/audio/synth/synth_constants.dart';
import 'package:interval_ear/core/utils/deterministic_random.dart';
import 'package:interval_ear/features/training/domain/services/frequency_calculator.dart';

/// 合成拨弦音色：Karplus–Strong 弦合成 + 一阶全通分数延迟（架构 §5.5）。
///
/// 直接 `round(sr/freq)` 会让音高偏差最多 ±0.5 采样，高音区可达 20 音分——练耳
/// App 不可接受。必须用一阶全通滤波器补偿小数部分，把循环周期精确锁到
/// `exact = sr/freq` 个采样。
///
/// **跨平台字节一致铁律①**：白噪声激励**必须**用 [Xorshift32Random]（seed = N），
/// 禁止 `dart:math` 的 `Random()`——后者算法跨 Dart 版本不保证稳定，会让不同设备
/// 音色不同、golden 测试失效。
class PluckedVoice {
  PluckedVoice._();

  /// 弦阻尼系数（每次循环乘的衰减）。越接近 1 余音越长。
  static const double kKsDamping = 0.996;

  /// 两点平均低通系数（同时用于延迟线两端），模拟弦的「绷紧」高频衰减。
  static const double kKsBlend = 0.5;

  /// 起音淡入时长（毫秒），raised-cosine 防 click（对齐 KeyboardVoice）。
  static const double kAttackMs = 6.0;

  /// 收音淡出时长（毫秒），raised-cosine 防 click（对齐 KeyboardVoice）。
  static const double kReleaseMs = 40.0;

  /// 逐音符 RMS 响度均衡目标幅度（RMS，无量纲）。
  ///
  /// 取值来源（本地实测）：对「同根音 C4 上 13 个音程（MIDI 60..72）、
  /// durationMs=1100、sr=44100、**套完 raised-cosine 包络后**」的自然 RMS 取最小
  /// 值 `minRms = 1.163183e-2`（出现在最安静/最高的 MIDI 72），令
  /// `kTargetRms = 0.95 · minRms = 0.011050242645016735`。
  ///
  /// 于是 13 个音里最安静的 MIDI 72 增益 = 0.95、其余增益 < 0.95——**全部 ≤ 0.95
  /// 不放大**，守住峰值约束；所有音被缩放到 `0.95·minRms`，RMS 极差 → 0 dB
  /// （< 3 dB 验收）。峰值 ≤ 0.22·0.95 < 0.5，满足 plucked_voice_test 的
  /// 「峰值 < 0.5」约束。
  static const double kTargetRms = 0.011050242645016735;

  /// 响度均衡增益上限（安全兜底，正常 13 音程绝不触发）。
  ///
  /// 正常场景增益均 ≤ 0.95。仅极端安静/反常时长导致 `g > 1` 时封顶到 2.0：
  /// 峰值 `0.22·2 = 0.44 < 0.5` 仍安全，避免放大过头削波。
  static const double kMaxGain = 2.0;

  /// 渲染单音 PCM（Float32List，范围约 [-kVoiceGain, kVoiceGain]）。
  ///
  /// [midi] MIDI 音高；[durationMs] 时长（毫秒）；[sampleRate] 采样率。
  static Float32List render(int midi, int durationMs, int sampleRate) {
    final double freq = FrequencyCalculator.midiToFrequency(midi);
    final int sampleCount = (durationMs * sampleRate / 1000).round();
    final Float32List out = Float32List(sampleCount);
    if (sampleCount <= 0) {
      return out;
    }

    // 分数延迟：精确循环周期 exact = sr/freq 通常不是整数。
    final double exact = sampleRate / freq;
    // 关键修正（架构 §5.5 音高准确度验收）：实测本循环拓扑（两点平均低通 + 一阶全通）
    // 的总群延迟相对「整数延迟 n + 全通 frac」恒为 −0.5 采样（跨 C3–C6 全部 37 音一致，
    // 与音高无关）。故令「整数延迟 + 全通分数」之和 = exact + 0.5，使总循环周期
    // = (exact + 0.5) − 0.5 = exact（音高零偏差，< 1 音分）。
    final double periodTarget = exact + 0.5;
    int n = periodTarget.floor();
    if (n < 1) {
      n = 1; // 极低频兜底，正常训练音域（C3–C6）不会触发。
    }
    // frac ∈ [0, 1)：一阶全通补偿的小数部分。
    final double frac = periodTarget - n;
    // 一阶全通系数：令其群延迟（DC）≈ frac。
    // 推导：全通 H(z)=(a+z⁻¹)/(1+a·z⁻¹)，a=(1-frac)/(1+frac) 时 τ(0)=frac。
    final double a = (1 - frac) / (1 + frac);

    // 白噪声激励 —— 确定性伪随机，seed = N（铁律①）。
    // 延迟线用 Float64List 存储（铁律②：中间运算全 double，避免 float32 往返舍入）。
    final Float64List buffer = Float64List(n);
    final Xorshift32Random rng = Xorshift32Random(seed: n);
    for (int j = 0; j < n; j++) {
      buffer[j] = rng.nextDouble() * 2 - 1;
    }

    double apPrevIn = 0.0;
    double apPrevOut = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final int idx = i % n;
      final double x = buffer[idx];
      // raised-cosine 防 click 包络：首样本=0（无起音爆音）、尾样本→0（无释放爆音）。
      final double env = RaisedCosineEnvelope.value(
        index: i,
        sampleCount: sampleCount,
        attackMs: kAttackMs,
        releaseMs: kReleaseMs,
        sampleRate: sampleRate,
      );
      out[i] = x * env * SynthConstants.kVoiceGain;
      // 两点平均低通。
      final double lp = kKsBlend * x + kKsBlend * buffer[(i + 1) % n];
      // 一阶全通实现分数延迟。
      final double ap = a * lp + apPrevIn - a * apPrevOut;
      apPrevIn = lp;
      apPrevOut = ap;
      buffer[idx] = kKsDamping * ap;
    }

    // Bug B：逐音符 RMS 响度均衡（只衰减、不放大），守峰值约束（峰值 ≤ 0.22·2 < 0.5）。
    // 在「套完包络」的最终输出上测自然 RMS，整体线性缩放，使 13 音程同根音下
    // RMS 极差 → 0（< 3 dB 验收）。线性缩放不影响音高（自相关对整体增益尺度不变），
    // 也不影响确定性（纯函数、同输入同输出）。
    _normalizeLoudness(out, sampleCount);
    return out;
  }

  /// 逐音符 RMS 响度均衡：把 [samples]（长度 [sampleCount]）整体线性缩放到
  /// 自然 RMS == [kTargetRms]。
  ///
  /// - 增益 `g = kTargetRms / rms`；由于 `kTargetRms = 0.95·minRms`，正常 13 音程里
  ///   最安静的音 `g = 0.95`、其余 `g < 0.95`——**全部 ≤ 0.95 不放大**，守住峰值约束。
  /// - 安全兜底：极端安静/反常时长下 `g` 可能 > 1，限制 `g ≤ kMaxGain(2.0)`，
  ///   此时峰值 `0.22·2 = 0.44 < 0.5` 仍安全。
  /// - 全静音（`rms ≈ 0`）直接返回，避免除零 / NaN。
  static void _normalizeLoudness(Float32List samples, int sampleCount) {
    if (sampleCount <= 0) {
      return;
    }
    double sumSq = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final double s = samples[i];
      sumSq += s * s;
    }
    final double rms = math.sqrt(sumSq / sampleCount);
    if (rms <= 1e-12) {
      return;
    }
    double gain = kTargetRms / rms;
    if (gain > kMaxGain) {
      gain = kMaxGain;
    }
    for (int i = 0; i < sampleCount; i++) {
      samples[i] *= gain;
    }
  }

  /// 给定 MIDI 与采样率，返回 Karplus–Strong 循环周期（采样数，含小数）。
  ///
  /// 仅供单测 / 自相关校验参考，不参与合成主路径。
  static double loopPeriodSamples(int midi, int sampleRate) =>
      sampleRate / FrequencyCalculator.midiToFrequency(midi);
}
