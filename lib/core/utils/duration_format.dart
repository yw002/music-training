import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/utils/math_utils.dart';

/// 时长与数值的展示格式化。
///
/// 所有中文单位都经由 [AppStrings.unit]，这样 i18n 时不需要回头改这里的逻辑
/// （架构 §8.5）。数值本身在这里定小数位，保证同一指标在各页面呈现一致。
abstract final class DurationFormat {
  const DurationFormat._();

  /// 反应时间：`3.2 秒`。小于 0 视作 0。
  ///
  /// 固定 1 位小数，配合 tabular figures 保证列表里数字不跳宽。
  static String responseTime(Duration duration) {
    final seconds = MathUtils.clampDouble(
      duration.inMilliseconds / 1000.0,
      0,
      double.maxFinite,
    );
    return AppStrings.unit.seconds(seconds.toStringAsFixed(1));
  }

  /// 秒数（double 入口），用于已经算好的平均值。
  static String seconds(double value) => AppStrings.unit.seconds(
        MathUtils.clampDouble(value, 0, double.maxFinite).toStringAsFixed(1),
      );

  /// 训练时长：`4 分钟` / `1 小时 12 分钟` / `不到 1 分钟`。
  ///
  /// 为什么不显示秒：训练总时长的秒级精度对用户没有意义，反而让数字频繁跳动。
  static String sessionDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return AppStrings.unit.lessThanOneMinute;
    }
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 60) {
      return AppStrings.unit.minutes('$totalMinutes');
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final hoursText = AppStrings.unit.hours('$hours');
    if (minutes == 0) {
      return hoursText;
    }
    return '$hoursText ${AppStrings.unit.minutes('$minutes')}';
  }

  /// 计时器样式 `mm:ss`，用于训练页顶部走时。
  ///
  /// 分钟不补零到 3 位，因为单组训练不会超过 99 分钟。
  static String clock(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final minutes = total.inMinutes;
    final seconds = total.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// 次数：`1.8 次`。整数值省略小数位（`2 次` 而不是 `2.0 次`）。
  static String times(double value) {
    final clamped = MathUtils.clampDouble(value, 0, double.maxFinite);
    final text = clamped == clamped.roundToDouble()
        ? clamped.toStringAsFixed(0)
        : clamped.toStringAsFixed(1);
    return AppStrings.unit.times(text);
  }

  /// 百分比：`85%`。入参是 `[0, 1]` 的比例值（架构 §8.6：展示时才乘 100）。
  static String percent(double ratio) =>
      AppStrings.unit.percent(MathUtils.toPercent(ratio));

  /// 天数：`3 天`。
  static String days(int value) =>
      AppStrings.unit.days('${MathUtils.clampInt(value, 0, 1 << 31)}');

  /// 题数：`12 题`。
  static String questions(int value) =>
      AppStrings.unit.questions(MathUtils.clampInt(value, 0, 1 << 31));

  /// 相对日期：`今天` / `昨天` / `3 天前`（更早则回退到 `M月d日`）。
  ///
  /// [reference] 一律由调用方注入（架构 §8.7：禁止在被测代码里 `DateTime.now()`）。
  static String relativeDate(DateTime date, DateTime reference) {
    final localDate = DateTime(date.year, date.month, date.day);
    final localRef =
        DateTime(reference.year, reference.month, reference.day);
    final diffDays = localRef.difference(localDate).inDays;
    if (diffDays <= 0) {
      return AppStrings.unit.today;
    }
    if (diffDays == 1) {
      return AppStrings.unit.yesterday;
    }
    if (diffDays < 7) {
      return AppStrings.unit.daysAgo(diffDays);
    }
    return AppStrings.unit.monthDay(localDate.month, localDate.day);
  }
}
