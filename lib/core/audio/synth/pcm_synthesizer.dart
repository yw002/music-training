import 'dart:typed_data';

import 'package:interval_ear/core/audio/synth/keyboard_voice.dart';
import 'package:interval_ear/core/audio/synth/plucked_voice.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 单音 PCM 合成静态入口：按音色分发到对应 Voice（架构 §3.4 / §5.5）。
///
/// 这是序列层 [SequenceBuilder] 唯一调用的合成入口，隐藏两种音色的差异。
abstract final class PcmSynthesizer {
  /// 渲染一个 [midi] 音、[timbre] 音色、[durationMs] 时长的单音 PCM。
  ///
  /// 返回的 [Float32List] 范围约 [-kVoiceGain, kVoiceGain]，供序列层拼接 / 混音。
  /// 合成确定性：[midi]+[timbre]+[durationMs]+[sampleRate] 完全相同则输出逐字节一致。
  static Float32List renderNote(
    int midi,
    Timbre timbre,
    int durationMs,
    int sampleRate,
  ) {
    return switch (timbre) {
      Timbre.keyboard => KeyboardVoice.render(midi, durationMs, sampleRate),
      Timbre.plucked => PluckedVoice.render(midi, durationMs, sampleRate),
    };
  }
}
