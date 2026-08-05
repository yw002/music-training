import 'dart:math' as math;

import 'package:interval_ear/features/training/domain/algorithm_constants.dart';

/// MIDI ↔ 频率换算（架构 §5.3 的播放前置工具）。
///
/// 纯数学、零依赖、可单测。音频合成层（不在 domain）拿到 MIDI 号后调用这里
/// 得到 Hz，再去合成波形。采用十二平均律 + `A4 = 440 Hz` 的国际标准。
///
/// `dart:math` 是纯 Dart 库（不属于 `package:flutter`），领域层可以放心 import。
abstract final class FrequencyCalculator {
  const FrequencyCalculator._();

  /// 一个八度的半音数（频率每升一个八度翻倍）。
  static const int semitonesPerOctave = kSemitonesPerOctave;

  /// `ln 2`，用于换底。
  static const double _ln2 = 0.6931471805599453;

  /// 把 MIDI 号转成频率（Hz）：`f = 440 * 2^((pitch - 69) / 12)`。
  ///
  /// [pitch] 允许是小数（微分音 / 弯音），也允许超出训练音域——合成层可能出于
  /// 音色需要生成几个八度外的谐波，音域检查由调用方负责。
  static double midiToFrequency(num pitch) =>
      kA4Hz * math.pow(2, (pitch - kA4Midi) / semitonesPerOctave);

  /// 把频率（Hz）转成（可能非整数的）MIDI 号。
  ///
  /// [frequency] 必须 > 0，否则返回 `double.nan`——非法输入不静默降级成某个
  /// 看起来合理的音高，让调用方的 bug 立刻暴露。
  static double frequencyToMidi(num frequency) {
    if (frequency <= 0) {
      return double.nan;
    }
    return kA4Midi + semitonesPerOctave * (math.log(frequency / kA4Hz) / _ln2);
  }

  /// 取最接近 [frequency] 的整数 MIDI 号。非法输入返回 `null`。
  static int? nearestMidi(num frequency) {
    final midi = frequencyToMidi(frequency);
    return midi.isFinite ? midi.round() : null;
  }

  /// 两个 MIDI 号的频率比。用于校验「八度 = 2.0，纯五度 ≈ 1.4983」。
  static double ratioBetween(num lower, num upper) =>
      midiToFrequency(upper) / midiToFrequency(lower);

  /// 音分（cent）差：1 个半音 = 100 音分。
  static double centsBetween(num lower, num upper) =>
      (upper - lower).toDouble() * 100;
}
