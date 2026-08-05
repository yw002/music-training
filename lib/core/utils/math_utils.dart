import 'dart:math' as math;

/// 纯数值工具。
///
/// 之所以收进一个类而不是写成顶层函数：`clampDouble` / `lerpDouble` 与 `dart:ui`
/// 的同名顶层函数会冲突，加类名前缀可以避免 import 顺序影响可读性。
abstract final class MathUtils {
  const MathUtils._();

  /// 把 [value] 限制在 `[min, max]`。[min] > [max] 时抛 [ArgumentError]。
  static double clampDouble(double value, double min, double max) {
    if (min > max) {
      throw ArgumentError('min ($min) must be <= max ($max)');
    }
    if (value.isNaN) {
      return min;
    }
    return value < min ? min : (value > max ? max : value);
  }

  /// 把 [value] 限制在 `[min, max]`（整数版）。
  static int clampInt(int value, int min, int max) {
    if (min > max) {
      throw ArgumentError('min ($min) must be <= max ($max)');
    }
    return value < min ? min : (value > max ? max : value);
  }

  /// 线性插值：`t = 0` 返回 [a]，`t = 1` 返回 [b]。[t] 不做钳制，允许外推。
  static double lerp(double a, double b, double t) => a + (b - a) * t;

  /// [lerp] 的逆运算：求 [value] 在 `[a, b]` 中的归一化位置，结果钳制到 `[0, 1]`。
  ///
  /// `a == b` 时返回 0（而非 NaN），因为调用方通常是进度条这类展示逻辑。
  static double inverseLerp(double a, double b, double value) {
    if (a == b) {
      return 0;
    }
    return clampDouble((value - a) / (b - a), 0, 1);
  }

  /// 把 [value] 从 `[inMin, inMax]` 线性映射到 `[outMin, outMax]`，并钳制到输出区间。
  static double remap(
    double value,
    double inMin,
    double inMax,
    double outMin,
    double outMax,
  ) =>
      lerp(outMin, outMax, inverseLerp(inMin, inMax, value));

  /// 四舍五入到 [fractionDigits] 位小数。用于展示层，不用于存储。
  static double roundTo(double value, int fractionDigits) {
    if (fractionDigits < 0) {
      throw ArgumentError('fractionDigits must be >= 0, got $fractionDigits');
    }
    if (!value.isFinite) {
      return value;
    }
    final factor = math.pow(10, fractionDigits).toDouble();
    return (value * factor).roundToDouble() / factor;
  }

  /// 安全除法：[denominator] 为 0 时返回 [fallback]，不产生 `Infinity`/`NaN`。
  ///
  /// 正确率、平均用时这类统计量在「样本数为 0」时必须走这里，否则会把
  /// `NaN` 一路带到 UI 上显示成 "NaN%"。
  static double safeDivide(
    num numerator,
    num denominator, {
    double fallback = 0,
  }) {
    if (denominator == 0) {
      return fallback;
    }
    final result = numerator / denominator;
    return result.isFinite ? result : fallback;
  }

  /// 比例值 `[0, 1]` 转百分比整数（四舍五入），并钳制到 `[0, 100]`。
  static int toPercent(double ratio) =>
      clampInt((clampDouble(ratio, 0, 1) * 100).round(), 0, 100);

  /// 求平均值，空集合返回 [fallback]。
  static double average(Iterable<num> values, {double fallback = 0}) {
    if (values.isEmpty) {
      return fallback;
    }
    var sum = 0.0;
    var count = 0;
    for (final v in values) {
      sum += v;
      count++;
    }
    return sum / count;
  }

  /// 求分位数（线性插值法）。[p] 取 `[0, 1]`，空集合返回 [fallback]。
  ///
  /// `MotionGovernor` 用它计算 p90 帧耗时。
  static double percentile(
    List<num> values,
    double p, {
    double fallback = 0,
  }) {
    if (values.isEmpty) {
      return fallback;
    }
    final sorted = List<num>.of(values)..sort();
    if (sorted.length == 1) {
      return sorted.first.toDouble();
    }
    final position = clampDouble(p, 0, 1) * (sorted.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) {
      return sorted[lower].toDouble();
    }
    return lerp(
      sorted[lower].toDouble(),
      sorted[upper].toDouble(),
      position - lower,
    );
  }
}
