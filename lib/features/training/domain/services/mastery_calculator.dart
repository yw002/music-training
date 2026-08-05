import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/stats/interval_statistics.dart';

/// 掌握度计算（架构 §5.1）。
///
/// **纯函数 + 无状态**：掌握度是「给定统计 → 算出一个分」的确定性映射，
/// 不缓存、不读全局。这样 `IntervalStatistics` 就不必保存一份易过期的
/// `masteryScore`（见 `interval_statistics.dart` 顶部的两点偏离说明），也规避了
/// 与 `MasteryCalculator` 之间的循环依赖。
///
/// **§5.1 公式**（逐行对应验收 5 的 5 个用例）：
/// ```
/// n        = totalCount - uncertainCount        // 有效样本数
/// rawAcc   = correct / max(n, 1)                // 终身正确率
/// recent   = 最近 kRecentWindow 次有效答对比例   // 近期表现
/// conf     = n / (n + K)                         // 样本置信度
/// blended  = (1 - w) * rawAcc + w * recent       // w = kRecentWeight
/// mastery  = clamp(blended * conf, 0, 1)
/// ```
abstract final class MasteryCalculator {
  const MasteryCalculator._();

  /// 计算某音程的掌握度 `[0, 1]`。零历史时返回 0（落在 weak 桶）。
  ///
  /// **「练 2 题全对仍 weak」的来由**：n=2 → conf=2/7≈0.286，recent≈1，
  /// blended≈0.6，mastery≈0.286 < 0.5，因此即便全对也只是 weak。这正是
  /// 公式要的效果——样本太少不能假装掌握。
  static double compute(IntervalStatistics stats) {
    final n = stats.effectiveCount;
    if (n <= 0) {
      return 0.0;
    }
    final rawAcc = stats.correctCount / n;
    final recent = stats.recentAccuracy;
    final confidence = n / (n + kMasteryConfidenceK);
    final blended = (1 - kRecentWeight) * rawAcc + kRecentWeight * recent;
    final mastery = blended * confidence;
    if (mastery < 0) {
      return 0.0;
    }
    if (mastery > 1) {
      return 1.0;
    }
    return mastery;
  }

  /// 把掌握度分数映射到档位（§5.2 的组卷输入）。
  ///
  /// 阈值来自 `algorithm_constants.dart`，调参只动后者。边界用 `0.4999` / `0.7499`
  /// / `0.8999` 而非 `0.5` / `0.75` / `0.9`：浮点比较时，恰好等于边界（如 0.5）
  /// 必须稳定地落进 weak 而非 medium，否则「mastery 恰好 0.5」会出现
  /// 跨版本抖动。见验收 7 的边界用例。
  static MasteryBucket bucketOf({required double mastery}) {
    if (mastery < kMasteryWeakMax) {
      return MasteryBucket.weak;
    }
    if (mastery < kMasteryMediumMax) {
      return MasteryBucket.medium;
    }
    if (mastery < kMasteryStrongMax) {
      return MasteryBucket.strong;
    }
    return MasteryBucket.mastered;
  }

  /// 直接由统计算档位，等价于 `bucketOf(mastery: compute(stats))`。
  static MasteryBucket bucketOfStats(IntervalStatistics stats) =>
      bucketOf(mastery: compute(stats));

  /// 把一组音程按掌握度分桶，返回各档的**音程集合**。空档返回空集。
  ///
  /// 组卷算法（§5.2）拿到的就是这个结果：每个桶要出多少题，从对应集合里抽。
  static Map<MasteryBucket, Set<IntervalId>> bucketize(
    Iterable<IntervalStatistics> all,
  ) {
    final result = <MasteryBucket, Set<IntervalId>>{
      for (final bucket in MasteryBucket.values) bucket: <IntervalId>{},
    };
    for (final stats in all) {
      final bucket = bucketOfStats(stats);
      result[bucket]!.add(stats.interval);
    }
    return result;
  }

  /// 该音程是否「足够熟练到可以降频复习」。
  ///
  /// 组卷时把 mastered 桶大量降权（仅保留 10% 抽查），依据就是它。
  static bool isMastered(IntervalStatistics stats) =>
      compute(stats) >= kMasteryStrongMax;
}
