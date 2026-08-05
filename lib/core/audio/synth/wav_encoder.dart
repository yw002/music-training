import 'dart:typed_data';

/// WAV 编码（16-bit PCM / 单声道 / 小端），44 字节 RIFF 头（架构 §5.5 表格）。
///
/// 纯 Dart、零依赖、确定性：同一 `Float32List` 永远编码出**逐字节相同**的 WAV
/// ——这是「跨端听感一致」的落点（架构 §1.2.1）。
abstract final class WavEncoder {
  /// 把 [-1, 1] 的 Float32 样本编码成 16-bit 单声道 WAV 的字节流。
  ///
  /// 头部字段逐个按 §5.5 表格写入；样本 `int16 = clamp(round(f·32767), -32768, 32767)`。
  static Uint8List encodeMono16(Float32List samples, int sampleRate) {
    const int channels = 1;
    const int bits = 16;
    final int dataSize = samples.length * 2;
    final int byteRate = sampleRate * channels * (bits ~/ 8);
    const int blockAlign = channels * (bits ~/ 8);

    final Uint8List out = Uint8List(44 + dataSize);
    final ByteData bd = ByteData.sublistView(out);

    // "RIFF"
    out[0] = 0x52;
    out[1] = 0x49;
    out[2] = 0x46;
    out[3] = 0x46;
    // RIFF 块大小 = 36 + dataSize
    bd.setUint32(4, 36 + dataSize, Endian.little);
    // "WAVE"
    out[8] = 0x57;
    out[9] = 0x41;
    out[10] = 0x56;
    out[11] = 0x45;
    // "fmt "
    out[12] = 0x66;
    out[13] = 0x6d;
    out[14] = 0x74;
    out[15] = 0x20;
    // PCM 子块大小 = 16
    bd.setUint32(16, 16, Endian.little);
    // 音频格式 = 1（PCM）
    bd.setUint16(20, 1, Endian.little);
    // 声道数
    bd.setUint16(22, channels, Endian.little);
    // 采样率
    bd.setUint32(24, sampleRate, Endian.little);
    // 字节率
    bd.setUint32(28, byteRate, Endian.little);
    // 块对齐
    bd.setUint16(32, blockAlign, Endian.little);
    // 位深
    bd.setUint16(34, bits, Endian.little);
    // "data"
    out[36] = 0x64;
    out[37] = 0x61;
    out[38] = 0x74;
    out[39] = 0x61;
    // data 大小
    bd.setUint32(40, dataSize, Endian.little);

    // 样本：Float32 → Int16（小端）。中间用 double，避免 float32 截断。
    for (int i = 0; i < samples.length; i++) {
      final int s =
          (samples[i] * 32767.0).round().clamp(-32768, 32767).toInt();
      bd.setInt16(44 + i * 2, s, Endian.little);
    }
    return out;
  }

  /// WAV 头字节数（供单测断言）。
  static const int headerBytes = 44;
}
