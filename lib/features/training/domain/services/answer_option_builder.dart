import 'dart:math' as math;

import 'package:interval_ear/core/utils/iterable_extensions.dart';
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/services/confusion_analyzer.dart';
import 'package:interval_ear/features/training/domain/stats/confusion_matrix.dart';

/// 答案选项构造（架构 §5.4）。
///
/// **防位置泄露的硬约束**：无论哪种模式，返回的选项列表都按**半音数升序**排列，
/// 与正确答案的位置无关。绝不能出现「正确答案总在第一个 / 随机洗牌导致某些
/// 位置概率更高」这类问题——前者是明显泄露，后者会让用户在长期训练中形成
/// 位置偏好。升序是确定性的，用户能建立稳定的空间记忆（这是好事，属于
/// 「音程网格」的一部分），但不携带任何本题答案信息。
abstract final class AnswerOptionBuilder {
  const AnswerOptionBuilder._();

  /// 按模式构造选项。
  ///
  /// - [AnswerMode.allIntervals]：13 个音程全列（固定网格）。
  /// - [AnswerMode.enabledOnly]：只列本次训练启用的音程。
  /// - [AnswerMode.binary]：正确答案 + 1 个干扰项，见 [buildBinary]。
  ///
  /// [enabled] 为空时降级为全部音程——空选项列表会让 UI 无从渲染，
  /// 属于必须兜底的场景。
  static List<IntervalId> build({
    required AnswerMode mode,
    required IntervalId correct,
    required Set<IntervalId> enabled,
    required math.Random random,
    ConfusionMatrix? confusion,
    IntervalPair? focusPair,
  }) {
    switch (mode) {
      case AnswerMode.allIntervals:
        return IntervalCatalog.sorted(IntervalCatalog.allIds);
      case AnswerMode.enabledOnly:
        final pool = enabled.isEmpty
            ? IntervalCatalog.allIds.toSet()
            : <IntervalId>{...enabled, correct};
        return IntervalCatalog.sorted(pool);
      case AnswerMode.binary:
        return buildBinary(
          correct: correct,
          enabled: enabled,
          random: random,
          confusion: confusion,
          focusPair: focusPair,
        );
    }
  }

  /// 构造二选一选项：`[正确答案, 干扰项]` 按半音数升序。
  ///
  /// 干扰项来源优先级：
  /// 1. **指定的焦点对**（[focusPair]）：二选一强化训练里对是选好的，直接用另一侧。
  /// 2. **历史混淆项**：以 [kConfusionBias] 的概率，从用户最常把 [correct]
  ///    误选成的前 [kTopConfusedLimit] 个里挑一个。这让强化训练打在真痛点上。
  /// 3. **随机相邻项**：兜底。优先取半音距离近的，因为距离越近越难分辨，
  ///    出一个「P1 vs P8」的二选一没有训练价值。
  ///
  /// 为什么不 100% 用历史混淆项：那样干扰项会完全可预测（「练 m6 必配 M6」），
  /// 用户会退化成背对子而不是听音程。[kConfusionBias] = 0.6 在「打痛点」与
  /// 「保持不可预测」之间取平衡。
  static List<IntervalId> buildBinary({
    required IntervalId correct,
    required Set<IntervalId> enabled,
    required math.Random random,
    ConfusionMatrix? confusion,
    IntervalPair? focusPair,
  }) {
    final distractor = pickDistractor(
      correct: correct,
      enabled: enabled,
      random: random,
      confusion: confusion,
      focusPair: focusPair,
    );
    return IntervalCatalog.sorted(<IntervalId>{correct, distractor});
  }

  /// 挑一个干扰项（不等于 [correct]）。
  ///
  /// 极端兜底：若候选池被过滤到空（例如只启用了 1 个音程），退回到
  /// 「半音距离最近的其他音程」，保证永远能返回一个合法值。
  static IntervalId pickDistractor({
    required IntervalId correct,
    required Set<IntervalId> enabled,
    required math.Random random,
    ConfusionMatrix? confusion,
    IntervalPair? focusPair,
  }) {
    // 1. 焦点对优先。
    if (focusPair != null && focusPair.contains(correct)) {
      final other = focusPair.other(correct);
      if (other != null && other != correct) {
        return other;
      }
    }

    // 2. 以 kConfusionBias 概率走历史混淆项。
    if (confusion != null && random.nextDouble() < kConfusionBias) {
      final candidates = ConfusionAnalyzer.topConfusedWith(
        correct,
        confusion,
        limit: kTopConfusedLimit,
      ).where((id) => id != correct).toList(growable: false);
      if (candidates.isNotEmpty) {
        return candidates[random.nextInt(candidates.length)];
      }
    }

    // 3. 随机相邻项：从启用集合里挑，按半音距离升序取最近的若干个再随机。
    final pool = (enabled.isEmpty ? IntervalCatalog.allIds.toSet() : enabled)
        .where((id) => id != correct)
        .toList(growable: false);
    if (pool.isNotEmpty) {
      final sorted = List<IntervalId>.of(pool)
        ..sort((a, b) {
          final byDistance = correct
              .semitoneDistanceTo(a)
              .compareTo(correct.semitoneDistanceTo(b));
          if (byDistance != 0) {
            return byDistance;
          }
          // 同距离时按半音数升序，保证同一随机序列产生同一结果。
          return a.semitones.compareTo(b.semitones);
        });
      final nearCount =
          sorted.length < kTopConfusedLimit ? sorted.length : kTopConfusedLimit;
      return sorted[random.nextInt(nearCount)];
    }

    // 4. 最终兜底：全表里离 correct 最近的那个。
    final fallback = IntervalCatalog.allIds
        .where((id) => id != correct)
        .toList(growable: false)
        .minByOrNull((id) => correct.semitoneDistanceTo(id));
    return fallback ?? IntervalId.defaultValue;
  }
}
