import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/utils/deterministic_random.dart';

/// T01 验收项：`Xorshift32Random(seed: 42)` 的前若干个输出必须逐值锁死。
///
/// 这些锚点值是「跨端出题序列一致」的唯一保证：只要 Android / Windows / macOS /
/// iOS 上这组断言全绿，同一 seed 就一定生成同一套题目。任何算法改动都会在这里炸。
void main() {
  group('Xorshift32Random 锚点序列', () {
    /// seed = 42 的前 10 个 `nextUint32()`。
    const List<int> expectedUint32 = <int>[
      11355432,
      2836018348,
      476557059,
      3648046016,
      3759983556,
      1441438134,
      3713466840,
      2431644334,
      3120216979,
      1067267639,
    ];

    test('nextUint32 前 10 个值逐一匹配', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 42);
      final List<int> actual = <int>[
        for (int i = 0; i < 10; i++) rng.nextUint32(),
      ];
      expect(actual, expectedUint32);
    });

    test('nextDouble 前 5 个值 = uint32 / 2^32', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 42);
      const double twoPow32 = 4294967296.0;
      for (int i = 0; i < 5; i++) {
        expect(rng.nextDouble(), closeTo(expectedUint32[i] / twoPow32, 1e-15));
      }
    });

    test('nextInt(13) 前 10 个值 = uint32 % 13（13 个音程的出题口径）', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 42);
      final List<int> actual = <int>[
        for (int i = 0; i < 10; i++) rng.nextInt(13),
      ];
      expect(actual, <int>[10, 7, 4, 4, 4, 6, 5, 2, 9, 9]);
      expect(actual.every((int v) => v >= 0 && v < 13), isTrue);
    });

    test('相同 seed 的两个实例序列完全一致', () {
      final Xorshift32Random a = Xorshift32Random(seed: 2024);
      final Xorshift32Random b = Xorshift32Random(seed: 2024);
      for (int i = 0; i < 200; i++) {
        expect(a.nextUint32(), b.nextUint32());
      }
    });

    test('不同 seed 的序列不同', () {
      final Xorshift32Random a = Xorshift32Random(seed: 1);
      final Xorshift32Random b = Xorshift32Random(seed: 2);
      final List<int> sa = <int>[for (int i = 0; i < 20; i++) a.nextUint32()];
      final List<int> sb = <int>[for (int i = 0; i < 20; i++) b.nextUint32()];
      expect(sa, isNot(sb));
    });
  });

  group('Xorshift32Random 状态与边界', () {
    test('seed = 0 退化到黄金比常数而不是死循环 0', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 0);
      expect(rng.state, 0x9E3779B9);
      final List<int> out = <int>[for (int i = 0; i < 10; i++) rng.nextUint32()];
      expect(out.every((int v) => v != 0), isTrue);
    });

    test('seed 高于 32 位会被掩码', () {
      final Xorshift32Random a = Xorshift32Random(seed: 0x1_0000_002A);
      final Xorshift32Random b = Xorshift32Random(seed: 42);
      expect(a.state, b.state);
      expect(a.nextUint32(), b.nextUint32());
    });

    test('保存 state 后恢复可续接同一序列（存档续训场景）', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 7);
      for (int i = 0; i < 5; i++) {
        rng.nextUint32();
      }
      final int saved = rng.state;
      final List<int> continued = <int>[
        for (int i = 0; i < 10; i++) rng.nextUint32(),
      ];

      final Xorshift32Random restored = Xorshift32Random(seed: 1)
        ..state = saved;
      final List<int> replayed = <int>[
        for (int i = 0; i < 10; i++) restored.nextUint32(),
      ];
      expect(replayed, continued);
    });

    test('state 置 0 同样退化到黄金比常数', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 9)..state = 0;
      expect(rng.state, 0x9E3779B9);
    });

    test('输出恒在 32 位无符号范围内', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 123456789);
      for (int i = 0; i < 5000; i++) {
        final int v = rng.nextUint32();
        expect(v, greaterThan(0));
        expect(v, lessThanOrEqualTo(0xFFFFFFFF));
      }
    });

    test('nextInt 非法 max 抛 RangeError', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 1);
      expect(() => rng.nextInt(0), throwsRangeError);
      expect(() => rng.nextInt(-3), throwsRangeError);
      expect(() => rng.nextInt(0x100000001), throwsRangeError);
    });

    test('nextDouble 恒在 [0, 1)', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 555);
      for (int i = 0; i < 3000; i++) {
        final double v = rng.nextDouble();
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });

    test('nextDoubleInRange / nextIntInRange 边界与异常', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 31);
      for (int i = 0; i < 500; i++) {
        final double d = rng.nextDoubleInRange(-2.5, 4.5);
        expect(d, greaterThanOrEqualTo(-2.5));
        expect(d, lessThan(4.5));
      }
      for (int i = 0; i < 500; i++) {
        final int n = rng.nextIntInRange(3, 9);
        expect(n, greaterThanOrEqualTo(3));
        expect(n, lessThanOrEqualTo(9));
      }
      expect(rng.nextIntInRange(5, 5), 5);
      expect(() => rng.nextDoubleInRange(1, 1), throwsArgumentError);
      expect(() => rng.nextIntInRange(4, 3), throwsArgumentError);
    });

    test('pickWeighted 只会命中权重为正的下标', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 88);
      const List<double> weights = <double>[0, 3, 0, 1, 0];
      final Set<int> hit = <int>{};
      for (int i = 0; i < 2000; i++) {
        hit.add(rng.pickWeighted(weights));
      }
      expect(hit, <int>{1, 3});
    });

    test('pickWeighted 分布大致符合权重比例', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 4242);
      const List<double> weights = <double>[1, 3];
      int ones = 0;
      const int total = 20000;
      for (int i = 0; i < total; i++) {
        if (rng.pickWeighted(weights) == 1) {
          ones++;
        }
      }
      expect(ones / total, closeTo(0.75, 0.02));
    });

    test('pickWeighted 非法入参抛 ArgumentError', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 1);
      expect(() => rng.pickWeighted(<double>[]), throwsArgumentError);
      expect(() => rng.pickWeighted(<double>[1, -1]), throwsArgumentError);
      expect(() => rng.pickWeighted(<double>[0, 0]), throwsArgumentError);
    });

    test('nextBool 两个取值都出现且大致均衡', () {
      final Xorshift32Random rng = Xorshift32Random(seed: 606);
      int trues = 0;
      const int total = 10000;
      for (int i = 0; i < total; i++) {
        if (rng.nextBool()) {
          trues++;
        }
      }
      expect(trues / total, closeTo(0.5, 0.03));
    });
  });
}
