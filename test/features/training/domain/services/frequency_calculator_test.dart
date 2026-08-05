// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/features/training/domain/services/frequency_calculator.dart';

/// T06 验收：频率换算（§5.3 音频合成基础）。
void main() {
  group('midi ↔ frequency', () {
    test('A4(69) = 440Hz', () {
      expect(FrequencyCalculator.midiToFrequency(69), closeTo(440, 1e-9));
      expect(FrequencyCalculator.midiToFrequency(69.0), closeTo(440, 1e-9));
    });

    test('八度翻倍：MIDI 81 = 880Hz', () {
      expect(FrequencyCalculator.midiToFrequency(81), closeTo(880, 1e-9));
    });

    test('frequency -> midi 往返', () {
      for (final midi in <num>[48, 60, 67, 72, 84]) {
        final freq = FrequencyCalculator.midiToFrequency(midi);
        final back = FrequencyCalculator.frequencyToMidi(freq);
        expect(back, closeTo(midi.toDouble(), 1e-9));
      }
    });

    test('非正频率返回 NaN 而非抛异常', () {
      expect(FrequencyCalculator.frequencyToMidi(0).isNaN, isTrue);
      expect(FrequencyCalculator.frequencyToMidi(-5).isNaN, isTrue);
    });

    test('nearestMidi 取整', () {
      // 440Hz 对应 69.0；443Hz 应近似 69。
      expect(
        FrequencyCalculator.nearestMidi(440.0),
        isNotNull,
      );
      final m = FrequencyCalculator.nearestMidi(
        FrequencyCalculator.midiToFrequency(69) * 1.01,
      );
      expect(m, anyOf(69, 70));
    });
  });

  group('ratio & cents', () {
    test('等比八度 = 2 倍频率，间隔 1200 cents', () {
      // ratioBetween / centsBetween 均以 MIDI 号（而非 Hz）为入参。
      expect(FrequencyCalculator.ratioBetween(60, 72), closeTo(2.0, 1e-9));
      expect(FrequencyCalculator.centsBetween(60, 72), closeTo(1200, 1e-6));
    });

    test('半音 = 100 cents（centsBetween 入参为 MIDI 号）', () {
      expect(FrequencyCalculator.centsBetween(60, 61), closeTo(100, 1e-6));
    });
  });
}
