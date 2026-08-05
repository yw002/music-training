import 'package:interval_ear/features/training/domain/stats/daily_summary.dart';

/// 连续打卡计算（架构 §3.2）。
///
/// **为什么「当前连续」在 midnight 会归零**：打卡的本质是「用户主观日历是否
/// 连续」。若以 UTC 午夜切分，`2024-06-20 23:30` 练完、第二天
/// `2024-06-21 00:10` 就练，会被算成隔了「一整天」而断签——而用户明明是
/// 连续两个晚上。所有日期边界都用**本地时区**（[DateKeys]），与
/// [DailySummary] 的口径一致。
///
/// **时钟注入**：为了可测（验收要求「clock-injected」），这里不调用
/// `DateTime.now()`，而是接收 [clock]。真实调用方传 `() => DateTime.now()`，
/// 测试传一个可调的闭包即可确定性地断言「昨天断签后今天归零」等场景。
abstract final class StreakCalculator {
  const StreakCalculator._();

  /// 计算连续打卡结果。
  ///
  /// [clock] 返回「当前时刻」（默认 `DateTime.now`）。只统计当天有至少一题
  /// 有效作答的 [DailySummary]——纯围观、空划水的一天不计入打卡。
  static StreakResult compute(
    Map<String, DailySummary> daily, {
    DateTime Function() clock = DateTime.now,
  }) {
    final now = clock();
    final todayKey = DateKeys.of(now);

    // 只保留「真的练了」的日期，并按字典序（=时间序）升序排列。
    final active =
        daily.entries
            .where((e) => e.value.isActive && DateKeys.isValid(e.key))
            .map((e) => e.key)
            .toList()
          ..sort(DateKeys.compare);
    if (active.isEmpty) {
      return StreakResult.empty;
    }

    final longest = _longestRun(active);
    final current = _currentRun(active, todayKey);
    final lastActive = active.last;
    final todayActive = lastActive == todayKey;
    final yesterdayKey = DateKeys.addDays(todayKey, -1);
    final yesterdayActive = lastActive == yesterdayKey;
    return StreakResult(
      current: current,
      longest: longest,
      lastActiveDateKey: lastActive,
      isTodayActive: todayActive,
      isYesterdayActive: yesterdayActive,
    );
  }

  /// 整段历史里的最长连续天数。
  static int _longestRun(List<String> sortedKeys) {
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sortedKeys.length; i++) {
      final gap = DateKeys.differenceInDays(sortedKeys[i - 1], sortedKeys[i]);
      if (gap == 1) {
        run += 1;
        if (run > longest) {
          longest = run;
        }
      } else {
        run = 1;
      }
    }
    return longest;
  }

  /// 截至今天的当前连续天数；若最近一次活跃既非今天也非昨天则归零。
  static int _currentRun(List<String> sortedKeys, String todayKey) {
    final lastActive = sortedKeys.last;
    final gap = DateKeys.differenceInDays(lastActive, todayKey);
    if (gap != 0 && gap != 1) {
      return 0;
    }
    // 从末尾往前数连续天数。
    var run = 0;
    var cursor = lastActive;
    for (var i = sortedKeys.length - 1; i >= 0; i--) {
      if (sortedKeys[i] != cursor) {
        break;
      }
      run += 1;
      final prev = DateKeys.addDays(cursor, -1);
      cursor = prev;
    }
    return run;
  }
}

/// 连续打卡的计算结果（无状态数据结构）。
class StreakResult {
  /// 创建结果。
  const StreakResult({
    required this.current,
    required this.longest,
    required this.lastActiveDateKey,
    required this.isTodayActive,
    required this.isYesterdayActive,
  });

  /// 当前连续天数（今天或昨天有练习才算连续）。
  final int current;

  /// 历史最长连续天数。
  final int longest;

  /// 最近一次练习的日期键。
  final String lastActiveDateKey;

  /// 今天是否已练习。
  final bool isTodayActive;

  /// 昨天是否已练习（用于「还差一天就断签」提示）。
  final bool isYesterdayActive;

  /// 零记录时的空结果。
  static const StreakResult empty = StreakResult(
    current: 0,
    longest: 0,
    lastActiveDateKey: '',
    isTodayActive: false,
    isYesterdayActive: false,
  );

  /// 是否处于「连续打卡中」。
  bool get hasStreak => current > 0;

  @override
  String toString() =>
      'StreakResult(current: $current, longest: $longest, '
      'lastActive: $lastActiveDateKey)';
}
