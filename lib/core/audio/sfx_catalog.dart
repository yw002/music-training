import 'dart:math' as math;
import 'dart:typed_data';

import 'package:interval_ear/core/audio/synth/envelope.dart';
import 'package:interval_ear/core/audio/synth/wav_encoder.dart';
import 'package:interval_ear/core/constants/app_config.dart';

/// 音效标识（架构 §3.4：`AudioService.playSfx(SfxId id)`）。
///
/// 音效是**独立于题目**的 UI 反馈（答对/答错/点击），绝不携带音高信息，不参与
/// 任何防泄露设计——它们本身就是「非训练音」。
enum SfxId {
  /// 答对提示（明亮短音）。
  correct,

  /// 答错提示（低沉短音）。
  wrong,

  /// 节拍 / 重播点击的极短 tick。
  tick,

  /// 通用 UI 点击。
  uiTap,
}

/// 音效目录：把 [SfxId] 合成成一段 WAV（纯 Dart，无素材依赖）。
///
/// 为什么自己合成而不用素材：原规范禁止「来源不明或存在版权问题的音频素材」，
/// 且音效很短（30–180ms），正弦 + raised-cosine 包络足够，零包体开销。
abstract final class SfxCatalog {
  /// 各音效的（频率 Hz, 时长 ms）。
  static const Map<SfxId, (double freq, int durationMs)> _specs =
      <SfxId, (double, int)>{
    SfxId.correct: (660.0, 150),
    SfxId.wrong: (160.0, 200),
    SfxId.tick: (1000.0, 30),
    SfxId.uiTap: (440.0, 45),
  };

  /// 生成某音效的 WAV 字节流（16-bit / 单声道）。
  static Uint8List wavFor(SfxId id, {int sampleRate = AppConfig.sampleRate}) {
    final (double freq, int durationMs) = _specs[id]!;
    final int sampleCount = (durationMs * sampleRate / 1000).round();
    final Float32List samples = Float32List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      final double t = i / sampleRate;
      final double env = RaisedCosineEnvelope.value(
        index: i,
        sampleCount: sampleCount,
        attackMs: 3,
        releaseMs: 8,
        sampleRate: sampleRate,
      );
      samples[i] = math.sin(2 * math.pi * freq * t) * env * 0.5;
    }
    return WavEncoder.encodeMono16(samples, sampleRate);
  }
}
