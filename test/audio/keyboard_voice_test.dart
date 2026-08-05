import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/synth/keyboard_voice.dart';

/// T07 验收 1/2：键盘音色的单音长度、峰值 ≤1、起止无爆音、确定性。
void main() {
  const int sr = 44100;

  group('KeyboardVoice 基本几何与防 click', () {
    test('渲染长度 = round(durationMs * sr / 1000)', () {
      final Float32List a = KeyboardVoice.render(60, 1100, sr);
      expect(a.length, (1100 * sr / 1000).round());
      final Float32List b = KeyboardVoice.render(72, 500, sr);
      expect(b.length, (500 * sr / 1000).round());
    });

    test('峰值 ≤ 1（无削波）', () {
      double peak = 0.0;
      final Float32List a = KeyboardVoice.render(60, 1100, sr);
      for (final double s in a) {
        peak = math.max(peak, s.abs());
      }
      expect(peak, lessThanOrEqualTo(1.0));
      // 实际应在 0.22 量级（kVoiceGain * 谐波和）。
      expect(peak, lessThan(0.6));
    });

    test('T07 验收 1·起止无爆音：首样本 = 0、尾样本 ≈ 0', () {
      final Float32List a = KeyboardVoice.render(64, 1100, sr);
      expect(a.first, 0.0); // raised-cosine 首样本必为 0。
      expect(a.last.abs(), lessThan(1e-2));
    });

    test('不同音高产出不同波形（非恒定）', () {
      final Float32List low = KeyboardVoice.render(48, 300, sr);
      final Float32List high = KeyboardVoice.render(84, 300, sr);
      bool differ = false;
      for (int i = 0; i < low.length; i++) {
        if ((low[i] - high[i]).abs() > 1e-6) {
          differ = true;
          break;
        }
      }
      expect(differ, isTrue);
    });
  });

  group('KeyboardVoice 确定性（T07 验收 2）', () {
    test('同参数两次渲染逐样本完全一致（字节级）', () {
      final Float32List a = KeyboardVoice.render(60, 1100, sr);
      final Float32List b = KeyboardVoice.render(60, 1100, sr);
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(a[i], b[i], reason: '样本 $i 不一致');
      }
    });

    test('改变音色参数（midi/duration）会改变输出', () {
      final Float32List a = KeyboardVoice.render(60, 1100, sr);
      final Float32List b = KeyboardVoice.render(61, 1100, sr);
      final Float32List c = KeyboardVoice.render(60, 1200, sr);
      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
    });
  });
}
