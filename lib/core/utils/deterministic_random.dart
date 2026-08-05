import 'dart:math' as math;

/// 跨端、跨 Dart 版本完全确定的伪随机数发生器（xorshift32，Marsaglia 2003）。
///
/// 为什么不用 `dart:math` 的 `Random(seed)`：SDK 未承诺其算法在不同版本/平台上
/// 保持一致，而本项目要求「同一 seed 在 Android / Windows / macOS / iOS 上产生
/// 完全相同的出题序列与合成噪声」（架构 §8.7）。xorshift32 只用移位与异或，
/// 结果只取决于 32 位整数语义，因此是跨端可复现的。
///
/// 状态空间为 2^32-1（不含 0），周期 4294967295。
class Xorshift32Random implements math.Random {
  /// 用 [seed] 初始化。`seed == 0` 会让 xorshift 永久停在 0，因此替换为黄金比常数。
  Xorshift32Random({required int seed})
      : _state = (seed & _mask) == 0 ? _goldenRatio : (seed & _mask);

  /// 32 位掩码。
  static const int _mask = 0xFFFFFFFF;

  /// 2^32 / φ，作为 seed==0 时的替代种子。
  static const int _goldenRatio = 0x9E3779B9;

  /// 2^32，用于把 uint32 归一化到 [0, 1)。
  static const double _twoPow32 = 4294967296.0;

  int _state;

  /// 当前内部状态。用于「保存进度后恢复出题序列」的场景。
  int get state => _state;

  /// 从一个已保存的状态恢复。[value] 会被掩码到 32 位；0 会被替换为黄金比常数。
  set state(int value) => _state = (value & _mask) == 0 ? _goldenRatio : (value & _mask);

  /// 生成下一个 32 位无符号整数，范围 `[1, 2^32-1]`。
  ///
  /// 这是全部随机能力的唯一来源，锚点测试直接断言它的前若干个输出。
  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    _state = x & _mask;
    return _state;
  }

  @override
  int nextInt(int max) {
    if (max < 1 || max > 0x100000000) {
      throw RangeError.range(max, 1, 0x100000000, 'max');
    }
    // 取模会引入极小的分布偏斜（max=13 时约 3e-9），对出题分布完全可忽略，
    // 而拒绝采样会让「第 N 个随机数」依赖被拒绝次数，破坏跨端锚点的可读性。
    return nextUint32() % max;
  }

  @override
  double nextDouble() => nextUint32() / _twoPow32;

  @override
  bool nextBool() => (nextUint32() & 1) == 1;

  /// 返回 `[min, max)` 区间内的 double。`min >= max` 时抛 [ArgumentError]。
  double nextDoubleInRange(double min, double max) {
    if (min >= max) {
      throw ArgumentError('min ($min) must be < max ($max)');
    }
    return min + nextDouble() * (max - min);
  }

  /// 返回 `[min, max]` 闭区间内的整数。
  int nextIntInRange(int min, int max) {
    if (min > max) {
      throw ArgumentError('min ($min) must be <= max ($max)');
    }
    return min + nextInt(max - min + 1);
  }

  /// 按权重挑选下标。[weights] 必须非空且元素非负、总和为正。
  int pickWeighted(List<double> weights) {
    if (weights.isEmpty) {
      throw ArgumentError('weights must not be empty');
    }
    var total = 0.0;
    for (final w in weights) {
      if (w < 0) {
        throw ArgumentError('weights must be non-negative, got $w');
      }
      total += w;
    }
    if (total <= 0) {
      throw ArgumentError('weights must sum to a positive value');
    }
    final target = nextDouble() * total;
    var acc = 0.0;
    for (var i = 0; i < weights.length; i++) {
      acc += weights[i];
      if (target < acc) {
        return i;
      }
    }
    // 浮点累加误差可能让 target 略超 acc，落到最后一个非零权重项。
    return weights.length - 1;
  }

  @override
  String toString() => 'Xorshift32Random(state: $_state)';
}
