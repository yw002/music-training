import 'dart:math' as math;

import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/id_factory.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/services/answer_option_builder.dart';
import 'package:interval_ear/features/training/domain/services/confusion_analyzer.dart';
import 'package:interval_ear/features/training/domain/services/root_note_generator.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 单题装配（架构 §5.3 / §5.4 的落点，被 `AdaptiveQuestionPlanner` 调用）。
///
/// 本类**无状态**：它不持有随机序列、不记住上一题，所有随机性都来自注入的
/// [math.Random]（架构 §8.7，一律 `Xorshift32Random(seed)`）。这样出题序列只由
/// 「seed + 调用顺序」决定，天然可复现——验收 4 就是「同 seed 同序列」。
///
/// 「装配」指：在 [PlannedInterval]（已确定考哪个音程、从哪个桶来）之外，
/// 一次性掷出方向、音色、根音，并构造好选项，拼成最终可播放的
/// [IntervalQuestion]。
class QuestionGenerator {
  /// 装配一道题。
  ///
  /// [planned] 来自 `AdaptiveQuestionPlanner` 的桶分配；[config] 是用户配置；
  /// [random] / [now] 注入以保证可复现与可测；[snapshot] 提供历史混淆矩阵，
  /// 仅在二选一模式用于挑干扰项。
  static IntervalQuestion assemble({
    required PlannedInterval planned,
    required TrainingConfig config,
    required math.Random random,
    required DateTime now,
    StatsSnapshot? snapshot,
  }) {
    // 正解由组卷阶段决定（二选一的左右均衡在 AdaptiveQuestionPlanner 里由
    // BinaryAnswerBalancer 跨题维护，装配器不能自己再掷一次，否则会破坏均衡）。
    final correct = planned.correct;

    // 1) 方向：配置为具体方向时直接用，随机混合时在三个方向上均匀掷骰。
    final direction = config.direction.fixedDirection ??
        PlaybackDirection.values[random.nextInt(PlaybackDirection.values.length)];

    // 2) 音色：配置为具体音色时直接用，随机时掷骰。
    final timbre = config.timbreMode.fixedTimbre ??
        (random.nextBool() ? Timbre.keyboard : Timbre.plucked);

    // 3) 选项：二选一优先用焦点对，否则走通用构造。
    final mode = config.answerMode;
    final options = mode == AnswerMode.binary && planned.focusPair != null
        ? preparedBinaryOptions(planned.focusPair!)
        : AnswerOptionBuilder.build(
            mode: mode,
            correct: correct,
            enabled: config.enabledIntervals,
            random: random,
            confusion: snapshot?.confusionMatrix,
            focusPair: planned.focusPair,
          );

    // 4) 根音与目标音（防泄露窗口在这里生效）。
    final rootPlan = RootNoteGenerator.generate(
      semitones: correct.semitones,
      direction: direction,
      mode: config.rootMode,
      random: random,
    );

    return IntervalQuestion(
      questionId: IdFactory.question(now, random),
      correctInterval: correct,
      rootMidiNote: rootPlan.rootMidi,
      targetMidiNote: rootPlan.targetMidi,
      direction: direction,
      timbre: timbre,
      rootMode: config.rootMode,
      answerOptions: options,
      createdAt: now,
      bucket: planned.bucket,
      focusPair: planned.focusPair?.key(),
    );
  }

  /// 从焦点对直接给出「两个音程、按半音数升序」的二选一选项。
  ///
  /// 二选一强化的对是预先选好的，不需要再随机挑干扰项——挑了反而会破坏
  /// 「这一对到底是不是难分」的实验控制。
  static List<IntervalId> preparedBinaryOptions(IntervalPair pair) =>
      IntervalCatalog.sorted(pair.toSet());

  /// 从一道题反推其焦点对（二选一专用）。非二选一返回 `null`。
  static IntervalPair? focusPairOf(IntervalQuestion question) {
    if (!question.isBinary) {
      return null;
    }
    final options = question.answerOptions;
    if (options.length != kBinaryOptionCount) {
      return null;
    }
    return IntervalPair(options[0], options[1]);
  }

  /// 为「加练插题」选一个焦点对：优先用真实弱项，没有则取默认对。
  static IntervalPair pickDrillPair(StatsSnapshot snapshot, math.Random random) {
    final ranked = ConfusionAnalyzer.suggestPairs(snapshot);
    if (ranked.isEmpty) {
      // 新用户零历史：取默认对里随机一个，保证有题可加练。
      const defaults = ConfusionAnalyzer.defaultPairs;
      if (defaults.isEmpty) {
        return const IntervalPair(
          IntervalId.minorThird,
          IntervalId.majorThird,
        );
      }
      return defaults[random.nextInt(defaults.length)];
    }
    return ranked[random.nextInt(ranked.length)];
  }
}

/// 一道题「考哪个音程、从哪个桶来」的已规划单元（无状态数据）。
///
/// 与 [IntervalQuestion] 的区别：它只回答「出什么」，不含方向/根音/选项这些
/// 具体呈现，相当于组卷算法的输出、装配器的输入。
class PlannedInterval {
  /// 创建计划单元。
  const PlannedInterval({
    required this.correct,
    required this.bucket,
    this.focusPair,
  });

  /// 本题正解音程。
  final IntervalId correct;

  /// 来源桶（用于可解释性统计与分段）。
  final QuestionBucket bucket;

  /// 二选一模式下的焦点对（其他选项信息由 [QuestionGenerator] 补全）。
  final IntervalPair? focusPair;

  @override
  String toString() =>
      'PlannedInterval(${correct.storageId}, ${bucket.storageId}'
      '${focusPair != null ? ", ${focusPair!.key()}" : ""})';
}
