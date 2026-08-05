import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/synth/wav_encoder.dart';

/// 小端读取 16-bit 有符号整数（用于校验编码结果）。
int _readI16(Uint8List wav, int offset) {
  final int u = wav[offset] | (wav[offset + 1] << 8);
  return u >= 0x8000 ? u - 0x10000 : u;
}

/// T07 验收 1：WAV 头逐字节断言 + 与 dataSize 一致性 + 同输入两次编码字节完全相同。
void main() {
  group('WavEncoder 44 字节 RIFF/WAVE 头逐字段断言', () {
    test('标准单声道 16-bit WAV 头字段全部正确', () {
      const int sampleRate = 44100;
      final Float32List samples = Float32List.fromList(<double>[
        0.0,
        0.5,
        -0.5,
        1.0,
        -1.0,
      ]);
      final Uint8List wav = WavEncoder.encodeMono16(samples, sampleRate);

      // 总长度 = 44 字节头 + 数据。
      const int dataSize = 5 * 2;
      expect(wav.length, WavEncoder.headerBytes + dataSize);
      expect(wav.length, 44 + dataSize);

      // "RIFF"。
      expect(wav[0], 0x52);
      expect(wav[1], 0x49);
      expect(wav[2], 0x46);
      expect(wav[3], 0x46);

      // RIFF 块大小 = 36 + dataSize（小端 uint32）。
      final int riffSize = wav[4] | (wav[5] << 8) | (wav[6] << 16) | (wav[7] << 24);
      expect(riffSize, 36 + dataSize);

      // "WAVE"。
      expect(wav[8], 0x57);
      expect(wav[9], 0x41);
      expect(wav[10], 0x56);
      expect(wav[11], 0x45);

      // "fmt "。
      expect(wav[12], 0x66);
      expect(wav[13], 0x6d);
      expect(wav[14], 0x74);
      expect(wav[15], 0x20);

      // PCM 子块大小 = 16。
      final int sub1 = wav[16] | (wav[17] << 8) | (wav[18] << 16) | (wav[19] << 24);
      expect(sub1, 16);

      // 音频格式 = 1（PCM）。
      final int audioFormat = wav[20] | (wav[21] << 8);
      expect(audioFormat, 1);

      // 声道数 = 1。
      final int channels = wav[22] | (wav[23] << 8);
      expect(channels, 1);

      // 采样率。
      final int sr = wav[24] |
          (wav[25] << 8) |
          (wav[26] << 16) |
          (wav[27] << 24);
      expect(sr, sampleRate);

      // 字节率 = sampleRate * channels * (bits/8)。
      final int byteRate = wav[28] |
          (wav[29] << 8) |
          (wav[30] << 16) |
          (wav[31] << 24);
      expect(byteRate, sampleRate * 1 * 2);

      // 块对齐 = channels * (bits/8) = 2。
      final int blockAlign = wav[32] | (wav[33] << 8);
      expect(blockAlign, 2);

      // 位深 = 16。
      final int bits = wav[34] | (wav[35] << 8);
      expect(bits, 16);

      // "data"。
      expect(wav[36], 0x64);
      expect(wav[37], 0x61);
      expect(wav[38], 0x74);
      expect(wav[39], 0x61);

      // data 大小 = dataSize。
      final int dataChunk = wav[40] |
          (wav[41] << 8) |
          (wav[42] << 16) |
          (wav[43] << 24);
      expect(dataChunk, dataSize);
    });

    test('采样率变化后头部字段随之正确', () {
      final Float32List samples = Float32List(10);
      final Uint8List wav = WavEncoder.encodeMono16(samples, 22050);
      final int sr =
          wav[24] | (wav[25] << 8) | (wav[26] << 16) | (wav[27] << 24);
      expect(sr, 22050);
      final int byteRate = wav[28] |
          (wav[29] << 8) |
          (wav[30] << 16) |
          (wav[31] << 24);
      expect(byteRate, 22050 * 2);
    });

    test('数据段与 Float32 样本逐字节一致（小端 int16 截断）', () {
      final Float32List samples = Float32List.fromList(<double>[1.0, -1.0]);
      final Uint8List wav = WavEncoder.encodeMono16(samples, 44100);
      // 1.0 → round(1.0*32767)=32767；-1.0 → round(-1.0*32767)=-32767。
      // 源码用 32767.0 作对称乘子再 clamp 到 [-32768,32767]，故 -1.0 落到 -32767
      // 而非 -32768（两端不对称，但属既定编码行为，测试须与其一致）。
      final int first = _readI16(wav, 44);
      expect(first, 32767);
      final int second = _readI16(wav, 46);
      expect(second, -32767);
    });

    test('T07 验收 2·确定性：同输入两次编码字节完全相等', () {
      final Float32List samples = Float32List.fromList(<double>[
        for (int i = 0; i < 256; i++) (i % 7 - 3) / 4.0,
      ]);
      final Uint8List a = WavEncoder.encodeMono16(samples, 44100);
      final Uint8List b = WavEncoder.encodeMono16(samples, 44100);
      expect(a, b);
      // 逐字节核对。
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(a[i], b[i], reason: '字节 $i 不一致');
      }
    });

    test('空样本也能产出合法头', () {
      final Uint8List wav = WavEncoder.encodeMono16(Float32List(0), 44100);
      expect(wav.length, 44);
      final int dataChunk = wav[40] |
          (wav[41] << 8) |
          (wav[42] << 16) |
          (wav[43] << 24);
      expect(dataChunk, 0);
    });
  });
}
