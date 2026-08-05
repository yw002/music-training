import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/synth/envelope.dart';
import 'package:interval_ear/core/audio/synth/keyboard_voice.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// T08 验收 6 + §5.6：合成器用的 RaisedCosineEnvelope（防 click）与可视化用的
/// EnvelopeSampler 是两套独立常量——断言它们不同，防止有人「顺手统一」。
void main() {
  group('RaisedCosineEnvelope（合成器防 click 淡变）', () {
    test('首样本必为 0（无爆音）、尾样本趋近 0', () {
      const int sr = 44100;
      final double v0 = RaisedCosineEnvelope.value(
        index: 0,
        sampleCount: 1000,
        attackMs: 6,
        releaseMs: 40,
        sampleRate: sr,
      );
      expect(v0, 0.0);
      final double vLast = RaisedCosineEnvelope.value(
        index: 999,
        sampleCount: 1000,
        attackMs: 6,
        releaseMs: 40,
        sampleRate: sr,
      );
      expect(vLast, closeTo(0.0, 1e-6));
    });

    test('attack 段单调 0→1', () {
      const int sr = 44100;
      final int attack = (6 * sr / 1000).round();
      double prev = -1.0;
      for (int i = 0; i < attack; i++) {
        final double v = RaisedCosineEnvelope.value(
          index: i,
          sampleCount: 5000,
          attackMs: 6,
          releaseMs: 40,
          sampleRate: sr,
        );
        expect(v, inInclusiveRange(0.0, 1.0));
        expect(v, greaterThanOrEqualTo(prev - 1e-12));
        prev = v;
      }
      // attack 末尾接近 1。
      final double vEnd = RaisedCosineEnvelope.value(
        index: attack - 1,
        sampleCount: 5000,
        attackMs: 6,
        releaseMs: 40,
        sampleRate: sr,
      );
      expect(vEnd, closeTo(1.0, 1e-3));
    });

    test('release 段单调 1→0', () {
      const int sr = 44100;
      final int release = (40 * sr / 1000).round();
      const int n = 5000;
      double prev = 2.0;
      for (int i = n - release; i < n; i++) {
        final double v = RaisedCosineEnvelope.value(
          index: i,
          sampleCount: n,
          attackMs: 6,
          releaseMs: 40,
          sampleRate: sr,
        );
        expect(v, inInclusiveRange(0.0, 1.0));
        expect(v, lessThanOrEqualTo(prev + 1e-12));
        prev = v;
      }
    });

    test('中间段恒为 1', () {
      const int sr = 44100;
      final double v = RaisedCosineEnvelope.value(
        index: 1000,
        sampleCount: 5000,
        attackMs: 6,
        releaseMs: 40,
        sampleRate: sr,
      );
      expect(v, 1.0);
    });

    test('sampleCount <= 0 返回 0（边界安全）', () {
      expect(
        RaisedCosineEnvelope.value(
          index: 0,
          sampleCount: 0,
          attackMs: 6,
          releaseMs: 40,
          sampleRate: 44100,
        ),
        0.0,
      );
    });
  });

  group('EnvelopeSampler（可视化包络，§5.6）', () {
    test('shape 边界：shape(0)=0、shape(attackFrac)=1、shape(1)=0', () {
      expect(EnvelopeSampler.shape(0.0), 0.0);
      expect(EnvelopeSampler.shape(EnvelopeSampler.attackFrac), 1.0);
      expect(EnvelopeSampler.shape(1.0), 0.0);
    });

    test('包络输出恒在 [0,1] 且 attack 段单调上升、release 段单调下降', () {
      double prevUp = -1.0;
      for (double p = 0.0; p <= EnvelopeSampler.attackFrac; p += 0.01) {
        final double v = EnvelopeSampler.shape(p);
        expect(v, inInclusiveRange(0.0, 1.0));
        expect(v, greaterThanOrEqualTo(prevUp - 1e-12));
        prevUp = v;
      }
      double prevDown = 2.0;
      for (double p = EnvelopeSampler.attackFrac;
          p <= 1.0001;
          p += 0.01) {
        final double v = EnvelopeSampler.shape(p);
        expect(v, inInclusiveRange(0.0, 1.0));
        expect(v, lessThanOrEqualTo(prevDown + 1e-12));
        prevDown = v;
      }
    });

    test('amplitudeAt 与音色无关（防泄露：m2 与 M7 逐像素一致）', () {
      for (double ms = 0.0; ms <= 950.0; ms += 37.0) {
        final double a = EnvelopeSampler.amplitudeAt(Timbre.keyboard, ms);
        final double b = EnvelopeSampler.amplitudeAt(Timbre.plucked, ms);
        expect(a, b);
        expect(a, inInclusiveRange(0.0, 1.0));
      }
    });

    test('windowMs = kAttackMs + kReleaseMs = 950ms', () {
      expect(EnvelopeSampler.kAttackMs, 600);
      expect(EnvelopeSampler.kReleaseMs, 350);
      expect(EnvelopeSampler.windowMs, 950);
      expect(EnvelopeSampler.attackFrac, closeTo(600 / 950, 1e-9));
    });
  });

  group('T08 验收 6·防「顺手统一」：两套常量必须不同', () {
    test('可视化包络 600/350 与合成器 1100/0.55 明显不同', () {
      // 可视化包络起音/收音（毫秒）。
      expect(EnvelopeSampler.kAttackMs, 600);
      expect(EnvelopeSampler.kReleaseMs, 350);

      // 合成器真实时长（键盘）：单音时长 1100ms、衰减时间常数 0.55s。
      expect(KeyboardVoice.kNoteDuration, 1.100);
      expect(KeyboardVoice.kDecayTau, 0.55);

      // 关键护栏：两组的数值绝不能相等（单位也不同，这里直接比数值防退化）。
      expect(EnvelopeSampler.kAttackMs,
          isNot(equals((KeyboardVoice.kNoteDuration * 1000).round())));
      expect(EnvelopeSampler.kReleaseMs, isNot(equals(KeyboardVoice.kDecayTau)));
      // 可视化起音（600ms）本身也绝不能退化成合成器的 1100ms 或 0.55。
      expect(EnvelopeSampler.kAttackMs, isNot(1100));
      expect(EnvelopeSampler.kReleaseMs, isNot(0.55));
    });
  });
}
