import 'dart:math' as math;

import 'package:interval_ear/core/utils/iterable_extensions.dart';
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/course_preset.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/services/binary_answer_balancer.dart';
import 'package:interval_ear/features/training/domain/services/bucket_quota.dart';
import 'package:interval_ear/features/training/domain/services/confusion_analyzer.dart';
import 'package:interval_ear/features/training/domain/services/mastery_calculator.dart';
import 'package:interval_ear/features/training/domain/services/question_generator.dart';
import 'package:interval_ear/features/training/domain/services/session_segment.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 自适应组卷（架构 §5.2 + §5.7）。**这是整个训练体验的大脑。**
///
/// ## 流程
///
/// ```
/// 1. 掌握度分桶      MasteryCalculator.bucketize   → weak/medium/strong/mastered
/// 2. 配额分配        BucketQuota.allocate          → 各桶出几题（空桶顺延、weak 保底）
/// 3. 逐桶抽音程      _drawFromBucket               → 桶内均匀抽，避免连续 3 题同音程
/// 4. 分段重排        _buildSegments                → 热身 / 弱项攻坚 / 混合
/// 5. 逐题装配        QuestionGenerator.assemble    → 掷方向、音色、根音，构造选项
/// ```
///
/// ## 可复现性（验收 4）
///
/// 全流程唯一的随机源是注入的 [math.Random]。同一个
/// `Xorshift32Random(42)` 跑两次 [planSession]，会得到**完全相同**的 20 道题
/// （包括 ID 里的随机后缀）。这既是测试的抓手，也是「云端复盘用户某次训练」
/// 的基础。
///
/// ## 冷启动（新用户零历史）
///
/// [StatsSnapshot.isEmpty] 时所有音程都在 weak 桶，若直接按配额出题会一上来就
/// 铺满 13 个音程，对新手是灾难。因此零历史时**收缩到第一章的音程**
/// （[CourseChapters.one]），随着数据积累自然放开。这条路径必须不崩——
/// 验收 5 专门测它。
abstract final class AdaptiveQuestionPlanner {
  const AdaptiveQuestionPlanner._();

  /// 组一整套题。
  ///
  /// [config] 决定题数与启用音程；[snapshot] 提供历史（零历史走冷启动）；
  /// [random] / [now] 注入以保证可复现。[focusPair] 非空时进入二选一强化模式，
  /// 整组题都围绕这一对。
  static SessionPlan planSession({
    required TrainingConfig config,
    required StatsSnapshot snapshot,
    required math.Random random,
    required DateTime now,
    IntervalPair? focusPair,
  }) {
    final total = config.questionCount;
    if (total <= 0) {
      return SessionPlan(
        questions: const <IntervalQuestion>[],
        segments: const <SessionSegment>[],
        quota: BucketQuota(const <MasteryBucket, int>{}),
      );
    }

    final planned = focusPair != null
        ? _planBinary(
            pair: focusPair,
            total: total,
            random: random,
          )
        : _planAdaptive(
            config: config,
            snapshot: snapshot,
            total: total,
            random: random,
          );

    final segments = buildSegments(total);
    final ordered = _applySegments(planned.units, segments);

    final questions = <IntervalQuestion>[];
    for (final unit in ordered) {
      questions.add(
        QuestionGenerator.assemble(
          planned: unit,
          config: config,
          random: random,
          now: now,
          snapshot: snapshot,
        ),
      );
    }

    return SessionPlan(
      questions: List<IntervalQuestion>.unmodifiable(questions),
      segments: segments,
      quota: planned.quota,
    );
  }

  /// 自适应路径：按掌握度分桶配额抽题。
  static _PlannedBatch _planAdaptive({
    required TrainingConfig config,
    required StatsSnapshot snapshot,
    required int total,
    required math.Random random,
  }) {
    final pool = resolvePool(config: config, snapshot: snapshot);
    final buckets = MasteryCalculator.bucketize(
      pool.map(snapshot.intervalOf).toList(growable: false),
    );
    // 只保留仍在候选池里的音程（掌握度可能来自已被用户关掉的音程）。
    final filtered = <MasteryBucket, List<IntervalId>>{};
    for (final entry in buckets.entries) {
      final ids = entry.value.where(pool.contains).toList(growable: false);
      filtered[entry.key] = IntervalCatalog.sorted(ids);
    }
    final nonEmpty = <MasteryBucket>{
      for (final entry in filtered.entries)
        if (entry.value.isNotEmpty) entry.key,
    };

    final quota = BucketQuota.allocate(
      totalQuestions: total,
      nonEmpty: nonEmpty,
    );

    final units = <PlannedInterval>[];
    for (final bucket in MasteryBucket.values) {
      final count = quota.of(bucket);
      final candidates = filtered[bucket] ?? const <IntervalId>[];
      if (count <= 0 || candidates.isEmpty) {
        continue;
      }
      for (var i = 0; i < count; i++) {
        units.add(
          PlannedInterval(
            correct: candidates[random.nextInt(candidates.length)],
            bucket: _questionBucketOf(bucket),
          ),
        );
      }
    }

    // 配额可能因空桶而凑不满（例如 pool 只有 1 个音程且 total=20 时不会，
    // 但 total 与权重取整的组合仍可能差 1~2 题），用整池补齐。
    final fallbackPool = IntervalCatalog.sorted(pool);
    while (units.length < total && fallbackPool.isNotEmpty) {
      units.add(
        PlannedInterval(
          correct: fallbackPool[random.nextInt(fallbackPool.length)],
          bucket: QuestionBucket.randomProbe,
        ),
      );
    }

    final shuffled = units.shuffledWith(random);
    return _PlannedBatch(
      units: _breakLongRuns(shuffled, random),
      quota: quota,
    );
  }

  /// 二选一强化路径：整组都是同一对，左右由 [BinaryAnswerBalancer] 均衡。
  static _PlannedBatch _planBinary({
    required IntervalPair pair,
    required int total,
    required math.Random random,
  }) {
    final normalized = pair.normalized();
    final balancer = BinaryAnswerBalancer(pair: normalized);
    final units = <PlannedInterval>[
      for (var i = 0; i < total; i++)
        PlannedInterval(
          correct: balancer.nextCorrect(random),
          bucket: QuestionBucket.weakPair,
          focusPair: normalized,
        ),
    ];
    // 二选一不再洗牌：均衡器的输出顺序本身就是精心安排的，洗牌会破坏
    // 「不连续 3 次同侧」的硬约束。
    return _PlannedBatch(
      units: units,
      quota: BucketQuota(<MasteryBucket, int>{MasteryBucket.weak: total}),
    );
  }

  /// 决定候选音程池。
  ///
  /// - 有历史：用户启用的音程（[TrainingConfig.enabledIntervals]）。
  /// - 零历史：收缩到第一章（[CourseChapters.one]），与启用集合求交；
  ///   交集为空时退回启用集合，保证永远非空。
  static Set<IntervalId> resolvePool({
    required TrainingConfig config,
    required StatsSnapshot snapshot,
  }) {
    final enabled = config.enabledIntervals.isEmpty
        ? IntervalCatalog.trainableIds
        : config.enabledIntervals;
    if (!snapshot.isEmpty) {
      return enabled;
    }
    final chapterOne = CourseChapters.one.intervals;
    final intersection = enabled.intersection(chapterOne);
    return intersection.isEmpty ? enabled : intersection;
  }

  /// 按 §5.7 把一组题切成热身 / 弱项攻坚 / 混合三段。
  ///
  /// 边界用 `round` 而不是 `floor`：20 题时热身 = round(20 * 0.2) = 4，
  /// 弱项段结束于 round(20 * 0.7) = 14，混合段 6 题，加起来正好 20。
  /// 题数很少（如 5 题）时某些段会退化为空段，这是允许的——
  /// [SessionPlan.segments] 会过滤掉空段。
  static List<SessionSegment> buildSegments(int total) {
    if (total <= 0) {
      return const <SessionSegment>[];
    }
    final warmUpEnd = (total * kWarmUpSegmentRatio).round().clamp(0, total);
    final weakEnd =
        (total * kWeakFocusSegmentRatio).round().clamp(warmUpEnd, total);
    final segments = <SessionSegment>[
      SessionSegment(
        type: SessionSegmentType.warmUp,
        startIndex: 0,
        endIndex: warmUpEnd,
      ),
      SessionSegment(
        type: SessionSegmentType.weakFocus,
        startIndex: warmUpEnd,
        endIndex: weakEnd,
      ),
      SessionSegment(
        type: SessionSegmentType.mixed,
        startIndex: weakEnd,
        endIndex: total,
      ),
    ].where((s) => !s.isEmpty).toList(growable: false);
    return List<SessionSegment>.unmodifiable(segments);
  }

  /// 把「桶抽出来的题」按分段重排：热身段放掌握度最高的，弱项段放最弱的。
  ///
  /// 这样用户开局就有正反馈（热身答对），中段进入真正的挑战，末段综合检验。
  /// 排序键用「桶的强弱」而不是精确掌握度：后者要再查一次快照，且同桶内
  /// 的细微差别对体验没有影响。
  static List<PlannedInterval> _applySegments(
    List<PlannedInterval> units,
    List<SessionSegment> segments,
  ) {
    if (units.isEmpty || segments.isEmpty) {
      return units;
    }
    final warmUp = segments.firstWhereOrNull(
      (s) => s.type == SessionSegmentType.warmUp,
    );
    final weakFocus = segments.firstWhereOrNull(
      (s) => s.type == SessionSegmentType.weakFocus,
    );
    if (warmUp == null && weakFocus == null) {
      return units;
    }

    // 按「越弱排越前」排序，取两端填入对应段。
    final byWeakness = List<PlannedInterval>.of(units)
      ..sort((a, b) {
        final byBucket =
            _bucketRank(a.bucket).compareTo(_bucketRank(b.bucket));
        if (byBucket != 0) {
          return byBucket;
        }
        return a.correct.semitones.compareTo(b.correct.semitones);
      });

    final result = List<PlannedInterval>.filled(
      units.length,
      units.first,
      growable: false,
    );
    var weakCursor = 0;
    var strongCursor = byWeakness.length - 1;

    for (final segment in segments) {
      for (var i = segment.startIndex; i < segment.endIndex; i++) {
        if (i >= result.length) {
          break;
        }
        switch (segment.type) {
          case SessionSegmentType.warmUp:
            // 热身取最强的（最不容易错），并统一归到 warmUp 桶。
            result[i] = _withBucket(
              byWeakness[strongCursor],
              QuestionBucket.warmUp,
            );
            strongCursor--;
          case SessionSegmentType.weakFocus:
          case SessionSegmentType.mixed:
            result[i] = byWeakness[weakCursor];
            weakCursor++;
        }
      }
    }
    // 游标可能因段长与总数不一致而交叉，交叉部分保留原顺序即可（不会越界，
    // 因为总段长恒等于 units.length）。
    return List<PlannedInterval>.unmodifiable(result);
  }

  static PlannedInterval _withBucket(
    PlannedInterval unit,
    QuestionBucket bucket,
  ) =>
      PlannedInterval(
        correct: unit.correct,
        bucket: bucket,
        focusPair: unit.focusPair,
      );

  /// 打散「连续 3 题同一音程」（§5.2 的硬约束 [kMaxSameIntervalRun]）。
  ///
  /// 洗牌后仍可能出现长串（尤其是候选池只有 2~3 个音程时）。这里做一次线性
  /// 扫描：发现越界就从后面找一个不同的元素换过来。找不到（池里只剩一种音程）
  /// 时放弃——那是用户只启用了 1 个音程的合法配置，不该为此死循环。
  static List<PlannedInterval> _breakLongRuns(
    List<PlannedInterval> units,
    math.Random random,
  ) {
    if (units.length <= kMaxSameIntervalRun) {
      return List<PlannedInterval>.unmodifiable(units);
    }
    final result = List<PlannedInterval>.of(units);
    for (var i = kMaxSameIntervalRun; i < result.length; i++) {
      var isRun = true;
      for (var k = 1; k <= kMaxSameIntervalRun; k++) {
        if (result[i - k].correct != result[i].correct) {
          isRun = false;
          break;
        }
      }
      if (!isRun) {
        continue;
      }
      // 从 i 之后找一个不同音程的位置换过来。
      var swapped = false;
      for (var j = i + 1; j < result.length; j++) {
        if (result[j].correct != result[i].correct) {
          final tmp = result[i];
          result[i] = result[j];
          result[j] = tmp;
          swapped = true;
          break;
        }
      }
      if (!swapped) {
        // 后面全是同一个音程，尝试往前找（保持前面已满足的约束不被破坏：
        // 只与 i-kMaxSameIntervalRun-1 之前的位置交换）。
        for (var j = i - kMaxSameIntervalRun - 1; j >= 0; j--) {
          if (result[j].correct != result[i].correct) {
            final tmp = result[i];
            result[i] = result[j];
            result[j] = tmp;
            break;
          }
        }
      }
    }
    return List<PlannedInterval>.unmodifiable(result);
  }

  /// 掌握度桶 → 题目来源桶的映射（用于可解释性统计）。
  static QuestionBucket _questionBucketOf(MasteryBucket bucket) =>
      switch (bucket) {
        MasteryBucket.weak => QuestionBucket.weakPair,
        MasteryBucket.medium => QuestionBucket.recentWrong,
        MasteryBucket.strong => QuestionBucket.spacedReview,
        MasteryBucket.mastered => QuestionBucket.randomProbe,
      };

  /// 来源桶的「弱」排名，越小越弱。
  static int _bucketRank(QuestionBucket bucket) => switch (bucket) {
        QuestionBucket.weakPair => 0,
        QuestionBucket.recentWrong => 1,
        QuestionBucket.spacedReview => 2,
        QuestionBucket.randomProbe => 3,
        QuestionBucket.warmUp => 4,
      };

  /// 生成 [kExtraDrillQuestionCount] 道加练题（答错后即时插入，§5.7）。
  ///
  /// 加练固定走二选一：把刚答错的音程和用户最常与之混淆的那个摆在一起，
  /// 逼用户当场分辨，这是「错误 → 纠正」闭环里最有效的一环。
  static List<IntervalQuestion> planExtraDrill({
    required IntervalId missed,
    required TrainingConfig config,
    required StatsSnapshot snapshot,
    required math.Random random,
    required DateTime now,
    int count = kExtraDrillQuestionCount,
  }) {
    if (count <= 0) {
      return const <IntervalQuestion>[];
    }
    final confusedWith =
        ConfusionAnalyzer.mostConfusedWith(missed, snapshot.confusionMatrix) ??
            _nearestOther(missed);
    final pair = IntervalPair(missed, confusedWith).normalized();
    final drillConfig = config.copyWith(
      answerMode: AnswerMode.binary,
      enabledIntervals: pair.toSet(),
      questionCount: count,
    );
    final balancer = BinaryAnswerBalancer(pair: pair);
    final questions = <IntervalQuestion>[];
    for (var i = 0; i < count; i++) {
      questions.add(
        QuestionGenerator.assemble(
          planned: PlannedInterval(
            correct: balancer.nextCorrect(random),
            bucket: QuestionBucket.recentWrong,
            focusPair: pair,
          ),
          config: drillConfig,
          random: random,
          now: now,
          snapshot: snapshot,
        ),
      );
    }
    return List<IntervalQuestion>.unmodifiable(questions);
  }

  /// 找一个离 [id] 半音距离最近的其他音程（加练兜底）。
  static IntervalId _nearestOther(IntervalId id) =>
      IntervalCatalog.allIds
          .where((other) => other != id)
          .toList(growable: false)
          .minByOrNull((other) => id.semitoneDistanceTo(other)) ??
      IntervalId.defaultValue;
}

/// 一次组卷的完整结果。
class SessionPlan {
  /// 创建组卷结果。
  const SessionPlan({
    required this.questions,
    required this.segments,
    required this.quota,
  });

  /// 按出题顺序排列的题目。
  final List<IntervalQuestion> questions;

  /// 分段信息（空段已过滤）。
  final List<SessionSegment> segments;

  /// 各掌握度桶的配额（用于「今日推荐理由」展示）。
  final BucketQuota quota;

  /// 题数。
  int get length => questions.length;

  /// 是否为空计划。
  bool get isEmpty => questions.isEmpty;

  /// 下标 [index] 所属的分段；越界返回 `null`。
  SessionSegment? segmentAt(int index) => segments.firstWhereOrNull(
        (s) => index >= s.startIndex && index < s.endIndex,
      );

  @override
  String toString() =>
      'SessionPlan(${questions.length} 题, ${segments.length} 段, $quota)';
}

/// 组卷中间态：已选好音程、尚未装配成题目。
class _PlannedBatch {
  const _PlannedBatch({required this.units, required this.quota});

  final List<PlannedInterval> units;
  final BucketQuota quota;
}
