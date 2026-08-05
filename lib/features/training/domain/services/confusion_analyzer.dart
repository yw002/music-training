import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/services/mastery_calculator.dart';
import 'package:interval_ear/features/training/domain/stats/confusion_entry.dart';
import 'package:interval_ear/features/training/domain/stats/confusion_matrix.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 混淆分析（架构 §3.2 报告 + §5.2 弱项排行 + §5.4 干扰项来源）。
///
/// 全部方法都是**无状态纯查询**：给定矩阵/快照，输出确定的诊断结果。
/// 排序规则全部借用 [ConfusionMatrix] 内部的
/// 「次数降序 → 半音距离升序 → 半音数升序」，保证同一份数据在任何平台
/// 排出的报告完全一致。
abstract final class ConfusionAnalyzer {
  const ConfusionAnalyzer._();

  /// 冷启动兜底的默认易混对（零历史时用）。
  ///
  /// 不用「机械地取所有相邻半音对」，而是按视唱练耳教学中公认的高频混淆点
  /// 手工挑选：大小三度 / 大小六度 / 大小七度是「色彩相近」，
  /// 纯四-三全音-纯五是「位置相邻且都带空旷感」，大二-小三是初学者最早的坎。
  /// 这样新用户第一次进二选一强化就能练到真正有价值的对，而不是 P1/m2。
  static const List<IntervalPair> defaultPairs = <IntervalPair>[
    IntervalPair(IntervalId.minorThird, IntervalId.majorThird),
    IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth),
    IntervalPair(IntervalId.minorSeventh, IntervalId.majorSeventh),
    IntervalPair(IntervalId.perfectFourth, IntervalId.tritone),
    IntervalPair(IntervalId.tritone, IntervalId.perfectFifth),
    IntervalPair(IntervalId.majorSecond, IntervalId.minorThird),
  ];

  /// 用户把 [actual] 最常误选成哪个音程；从未错过则返回 `null`。
  ///
  /// 返回 `null` 而不是随便给一个，是因为调用方（干扰项生成）需要据此决定
  /// 「走历史混淆分支还是走随机分支」——见 §5.4 的 [kConfusionBias]。
  static IntervalId? mostConfusedWith(
    IntervalId actual,
    ConfusionMatrix matrix,
  ) {
    final entries = matrix.rowEntries(actual, limit: 1);
    return entries.isEmpty ? null : entries.first.selected;
  }

  /// 用户把 [actual] 最常误选成的前 [limit] 个音程（次数降序 → 距离升序）。
  static List<IntervalId> topConfusedWith(
    IntervalId actual,
    ConfusionMatrix matrix, {
    int limit = kTopConfusedLimit,
  }) {
    if (limit <= 0) {
      return const <IntervalId>[];
    }
    final entries = matrix.rowEntries(actual, limit: limit);
    return List<IntervalId>.unmodifiable(
      entries.map((e) => e.selected).toList(growable: false),
    );
  }

  /// 报告页展示的 TOP 混淆格（不含对角线）。
  static List<ConfusionEntry> topEntries(
    ConfusionMatrix matrix, {
    int limit = kConfusionTopCount,
  }) => matrix.topEntries(limit);

  /// 单个音程对的双向混淆诊断。
  static ConfusionDiagnosis diagnosePair(
    IntervalPair pair,
    ConfusionMatrix matrix,
  ) {
    final normalized = pair.normalized();
    final a = normalized.low;
    final b = normalized.high;
    return ConfusionDiagnosis(
      pair: normalized,
      lowToHigh: matrix.countOf(a, b),
      highToLow: matrix.countOf(b, a),
      total: matrix.rowTotal(a) + matrix.rowTotal(b),
    );
  }

  /// 按「值得优先攻坚的程度」排出最弱的若干音程对。
  ///
  /// 打分：
  /// ```
  /// normWrong = min(wrong / kWeakPairConfusionNormalizer, 1)
  /// gap       = 1 - min(mastery(low), mastery(high))   // 短板效应
  /// score     = kWeakPairConfusionWeight * normWrong
  ///           + kWeakPairMasteryWeight  * gap
  /// ```
  /// 两项缺一不可：只看混淆次数，练得多的音程会因为基数大而虚高；
  /// 只看掌握度，「练得少所以掌握度低」的冷门音程会挤掉真正的易混对。
  ///
  /// 排序：分数降序 → 半音距离升序 → 对键字典序（保证完全确定）。
  static List<WeakPair> rankPairs(
    StatsSnapshot snapshot, {
    int limit = kWeakPairRankCount,
  }) {
    if (limit <= 0) {
      return const <WeakPair>[];
    }
    final matrix = snapshot.confusionMatrix;
    // topPairs 已经把对称方向合并、并按次数排好；这里取全量再按综合分重排。
    final candidates = <WeakPair>[];
    for (final pair in matrix.topPairs(_allPairsUpperBound)) {
      final diagnosis = diagnosePair(pair, matrix);
      final masteryLow = MasteryCalculator.compute(
        snapshot.intervalOf(pair.low),
      );
      final masteryHigh = MasteryCalculator.compute(
        snapshot.intervalOf(pair.high),
      );
      final worst = masteryLow < masteryHigh ? masteryLow : masteryHigh;
      final normWrong = (diagnosis.wrong / kWeakPairConfusionNormalizer).clamp(
        0.0,
        1.0,
      );
      final score =
          kWeakPairConfusionWeight * normWrong +
          kWeakPairMasteryWeight * (1 - worst);
      candidates.add(
        WeakPair(
          pair: pair,
          confusionCount: diagnosis.wrong,
          totalCount: diagnosis.total,
          masteryLow: masteryLow,
          masteryHigh: masteryHigh,
          score: score,
        ),
      );
    }
    candidates.sort(_compareWeakPairs);
    return List<WeakPair>.unmodifiable(
      candidates.length <= limit ? candidates : candidates.sublist(0, limit),
    );
  }

  /// 给二选一强化推荐音程对：优先用真实弱项，不足时用 [defaultPairs] 补齐。
  ///
  /// 新用户零历史时 [rankPairs] 返回空列表，这里保证仍能给出 [limit] 个对，
  /// 满足「零历史不崩、有内容可练」的验收要求。
  static List<IntervalPair> suggestPairs(
    StatsSnapshot snapshot, {
    int limit = kWeakPairRankCount,
  }) {
    if (limit <= 0) {
      return const <IntervalPair>[];
    }
    final result = <IntervalPair>[];
    final seen = <String>{};
    for (final weak in rankPairs(snapshot, limit: limit)) {
      if (seen.add(weak.pair.key())) {
        result.add(weak.pair);
      }
    }
    for (final pair in defaultPairs) {
      if (result.length >= limit) {
        break;
      }
      if (seen.add(pair.key())) {
        result.add(pair);
      }
    }
    return List<IntervalPair>.unmodifiable(result);
  }

  /// 13 个音程两两组合的上界（`C(13,2) = 78`），用于「取全部对」。
  ///
  /// 写成常量而不是 `9999` 这种魔法数：`topPairs` 的参数语义是「取前 k 个」，
  /// 给一个有意义的上界能让读者立刻明白这是「全取」。
  static const int _allPairsUpperBound =
      kMaxSemitones * (kMaxSemitones + 1) ~/ 2;

  static int _compareWeakPairs(WeakPair a, WeakPair b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) {
      return byScore;
    }
    final byDistance = a.pair.semitoneDistance.compareTo(
      b.pair.semitoneDistance,
    );
    if (byDistance != 0) {
      return byDistance;
    }
    return a.pair.key().compareTo(b.pair.key());
  }
}

/// 一个音程对的双向混淆诊断（纯数据）。
class ConfusionDiagnosis {
  /// 创建诊断。
  const ConfusionDiagnosis({
    required this.pair,
    required this.lowToHigh,
    required this.highToLow,
    required this.total,
  });

  /// 音程对（已规范化）。
  final IntervalPair pair;

  /// 正确答案是 [IntervalPair.low] 却选了 high 的次数。
  final int lowToHigh;

  /// 正确答案是 [IntervalPair.high] 却选了 low 的次数。
  final int highToLow;

  /// 涉及该对任一侧的总作答次数。
  final int total;

  /// 双向选错总次数。
  int get wrong => lowToHigh + highToLow;

  /// 混淆率 `[0, 1]`；无样本为 0。
  double get rate => total == 0 ? 0 : wrong / total;

  /// 是否明显偏向一侧（一个方向的错误是另一方向的 3 倍以上）。
  ///
  /// 命中说明用户存在「一律猜某一边」的倾向，报告页应给出针对性提示。
  bool get isOneSided {
    final low = lowToHigh;
    final high = highToLow;
    if (low + high < 4) {
      return false;
    }
    return low > high * 3 || high > low * 3;
  }

  @override
  String toString() =>
      'ConfusionDiagnosis(${pair.key()}, $wrong/$total, ${rate.toStringAsFixed(2)})';
}

/// 弱项音程对排行项（纯数据）。
class WeakPair {
  /// 创建排行项。
  const WeakPair({
    required this.pair,
    required this.confusionCount,
    required this.totalCount,
    required this.masteryLow,
    required this.masteryHigh,
    required this.score,
  });

  /// 音程对（已规范化）。
  final IntervalPair pair;

  /// 双向选错次数。
  final int confusionCount;

  /// 涉及该对的总作答次数。
  final int totalCount;

  /// [IntervalPair.low] 的掌握度。
  final double masteryLow;

  /// [IntervalPair.high] 的掌握度。
  final double masteryHigh;

  /// 综合弱项分数（越大越该练）。
  final double score;

  /// 两者中较低的掌握度（短板）。
  double get worstMastery =>
      masteryLow < masteryHigh ? masteryLow : masteryHigh;

  /// 混淆率 `[0, 1]`。
  double get rate => totalCount == 0 ? 0 : confusionCount / totalCount;

  @override
  String toString() =>
      'WeakPair(${pair.key()}, score=${score.toStringAsFixed(3)}, '
      'confusion=$confusionCount)';
}
