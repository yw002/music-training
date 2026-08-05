import 'dart:isolate';
import 'dart:typed_data';

import 'package:interval_ear/core/audio/synth/pcm_synthesizer.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 在独立 Isolate 中渲染单音 PCM，避免 1.1s 长音的合成阻塞 UI 线程（架构 §5.5）。
///
/// **铁律③**：`Isolate.run` 不改变浮点语义——跨 Isolate 的合成结果与同步调用
/// [PcmSynthesizer.renderNote] 逐字节一致，因此 golden 测试在 Isolate 路径下同样成立。
///
/// Dart 3.12 的 `Isolate.run<R>` 不接收 message 参数，函数靠闭包捕获输入。为彻底避免
/// 任何跨 Isolate 序列化歧义（尤其枚举的可发送性），这里只捕获基础类型 `int`，在
/// 闭包内用 `timbreIndex` 还原 [Timbre]。
abstract final class SynthIsolate {
  /// 在后台 Isolate 中渲染，返回与同步 [PcmSynthesizer.renderNote] 完全一致的样本。
  static Future<Float32List> renderNote({
    required int midi,
    required Timbre timbre,
    required int durationMs,
    required int sampleRate,
  }) {
    final int timbreIndex = timbre.index;
    return Isolate.run<Float32List>(() {
      return PcmSynthesizer.renderNote(
        midi,
        Timbre.values[timbreIndex],
        durationMs,
        sampleRate,
      );
    });
  }
}
