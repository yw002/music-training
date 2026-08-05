import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 各掌握度桶应出多少题（架构 §5.2）。
///
/// 把配额计算从 `AdaptiveQuestionPlanner` 里独立出来，是因为「怎么分配题数」
/// 是纯算术、边界情况多（空桶、余数、保底），值得单独测。
class BucketQuota {
  /// 直接指定各桶题数（一般由 [allocate] 生成）。
  BucketQuota(Map<MasteryBucket, int> counts)
      : _counts = <MasteryBucket, int>{
          for (final bucket in MasteryBucket.values)
            bucket: counts[bucket] ?? 0,
        };

  final Map<MasteryBucket, int> _counts;

  /// 取某桶的配额。
  int of(MasteryBucket bucket) => _counts[bucket] ?? 0;

  /// 总题数。
  int get total {
    var sum = 0;
    for (final value in _counts.values) {
      sum += value;
    }
    return sum;
  }

  /// 只读视图。
  Map<MasteryBucket, int> toMap() =>
      Map<MasteryBucket, int>.unmodifiable(_counts);

  /// 各桶的默认权重（§5.2：weak 50% / medium 25% / strong 15% / mastered 10%）。
  static const Map<MasteryBucket, double> weights = <MasteryBucket, double>{
    MasteryBucket.weak: kBucketWeightWeak,
    MasteryBucket.medium: kBucketWeightMedium,
    MasteryBucket.strong: kBucketWeightStrong,
    MasteryBucket.mastered: kBucketWeightMastered,
  };

  /// 按权重把 [totalQuestions] 分配到各桶。
  ///
  /// ## 三条容易写错的规则
  ///
  /// 1. **空桶不参与分配**。若用户没有任何 weak 音程，那 50% 的份额不能凭空
  ///    出题——[nonEmpty] 里没有的桶配额恒为 0，其份额按
  ///    weak > medium > strong > mastered 的优先级**顺延**给还有内容的桶。
  /// 2. **余数归 weak**。按权重取整后总数通常小于 [totalQuestions]，
  ///    差额全部补给最需要练的桶（weak 非空时给 weak，否则给优先级最高的非空桶）。
  /// 3. **weak 保底**。只要 weak 非空，配额至少 [kWeakBucketMinQuota] 题——
  ///    避免「weak 只有 1 个音程、权重算下来取整成 0」导致薄弱项一整组都不出现。
  ///
  /// [nonEmpty] 是「当前有音程可出题」的桶集合。全空时返回全 0 配额
  /// （调用方应改走冷启动路径，见 `AdaptiveQuestionPlanner`）。
  static BucketQuota allocate({
    required int totalQuestions,
    required Set<MasteryBucket> nonEmpty,
  }) {
    final counts = <MasteryBucket, int>{
      for (final bucket in MasteryBucket.values) bucket: 0,
    };
    if (totalQuestions <= 0 || nonEmpty.isEmpty) {
      return BucketQuota(counts);
    }

    // 归一化非空桶的权重，空桶的份额自动被摊到其余桶上。
    var weightSum = 0.0;
    for (final bucket in nonEmpty) {
      weightSum += weights[bucket] ?? 0;
    }
    if (weightSum <= 0) {
      // 理论不可达（四个权重都为正），兜底成均分。
      final each = totalQuestions ~/ nonEmpty.length;
      for (final bucket in nonEmpty) {
        counts[bucket] = each;
      }
    } else {
      for (final bucket in nonEmpty) {
        final share = (weights[bucket] ?? 0) / weightSum;
        counts[bucket] = (totalQuestions * share).floor();
      }
    }

    // weak 保底。
    if (nonEmpty.contains(MasteryBucket.weak) &&
        counts[MasteryBucket.weak]! < kWeakBucketMinQuota) {
      counts[MasteryBucket.weak] = kWeakBucketMinQuota;
    }

    // 处理余数与超发。
    var assigned = 0;
    for (final value in counts.values) {
      assigned += value;
    }
    final priority = _priorityOrder(nonEmpty);
    if (assigned < totalQuestions && priority.isNotEmpty) {
      counts[priority.first] =
          counts[priority.first]! + (totalQuestions - assigned);
    } else if (assigned > totalQuestions) {
      // weak 保底可能导致超发（如 total=1 且四桶都非空），从优先级最低的桶回收。
      var excess = assigned - totalQuestions;
      for (final bucket in priority.reversed) {
        if (excess <= 0) {
          break;
        }
        final available = bucket == MasteryBucket.weak
            ? counts[bucket]! - kWeakBucketMinQuota
            : counts[bucket]!;
        if (available <= 0) {
          continue;
        }
        final take = available < excess ? available : excess;
        counts[bucket] = counts[bucket]! - take;
        excess -= take;
      }
      // 仍有超发说明 totalQuestions < weak 保底，此时以 totalQuestions 为准。
      if (excess > 0 && counts[MasteryBucket.weak]! >= excess) {
        counts[MasteryBucket.weak] = counts[MasteryBucket.weak]! - excess;
      }
    }

    return BucketQuota(counts);
  }

  /// 非空桶按「谁更该练」排序：weak > medium > strong > mastered。
  static List<MasteryBucket> _priorityOrder(Set<MasteryBucket> nonEmpty) =>
      <MasteryBucket>[
        MasteryBucket.weak,
        MasteryBucket.medium,
        MasteryBucket.strong,
        MasteryBucket.mastered,
      ].where(nonEmpty.contains).toList(growable: false);

  @override
  String toString() => 'BucketQuota(weak=${of(MasteryBucket.weak)}, '
      'medium=${of(MasteryBucket.medium)}, '
      'strong=${of(MasteryBucket.strong)}, '
      'mastered=${of(MasteryBucket.mastered)})';
}
