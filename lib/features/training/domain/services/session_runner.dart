import 'dart:math' as math;

import 'package:interval_ear/core/utils/math_utils.dart' show MathUtils;
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/id_factory.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/services/adaptive_question_planner.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 会话执行器（架构 §5.7）：把「组卷 → 逐题作答 → 累积统计 → 结算」串成一条
/// 有状态的工作流。
///
/// 设计取舍：
/// - **无状态的部分留在 [AdaptiveQuestionPlanner] / [QuestionGenerator]**。本类只
///   持有「这一次会话进行到哪了」的可变状态（游标、连击、插题队列），不自己出题。
/// - **随机源与时钟一律注入**（[math.Random] / [DateTime]）。同一个 seed 跑同一次
///   会话，得到的题目 ID、加练插入位置、最终统计完全可复现——验收 4 的延伸。
/// - **统计双写**：每答一题既更新 [StatsSnapshot]（供下一组组卷与报告），也更新
///   [TrainingSession]（供结算页）。两者都从 [TrainingAttempt] 重算，本类只是
///   「驱动器」，不制造第二个真相。
class SessionRunner {
  /// 创建并启动一次会话。
  ///
  /// [config] 是这一组不可变的配置；[priorSnapshot] 是会话开始前已有的历史；
  /// [random] / 起始 [now] 注入保证可复现；[focusPair] 非空进入二选一强化；
  /// [presetId] 用于 §5.7 的章节推进判定（今日推荐/自由训练为 `null`）；
  /// [trainingMode] 决定结算口径。
  factory SessionRunner.start({
    required TrainingConfig config,
    required StatsSnapshot priorSnapshot,
    required math.Random random,
    required DateTime now,
    IntervalPair? focusPair,
    String? presetId,
    TrainingMode trainingMode = TrainingMode.daily,
  }) {
    final sessionId = IdFactory.session(now, random);
    final plan = AdaptiveQuestionPlanner.planSession(
      config: config,
      snapshot: priorSnapshot,
      random: random,
      now: now,
      focusPair: focusPair,
    );
    return SessionRunner._(
      sessionId: sessionId,
      config: config,
      priorSnapshot: priorSnapshot,
      random: random,
      trainingMode: trainingMode,
      focusPair: focusPair,
      presetId: presetId,
      startedAt: now,
      plan: plan,
    );
  }

  SessionRunner._({
    required String sessionId,
    required TrainingConfig config,
    required StatsSnapshot priorSnapshot,
    required math.Random random,
    required TrainingMode trainingMode,
    required this.focusPair,
    required this.presetId,
    required DateTime startedAt,
    required SessionPlan plan,
  })  : _priorSnapshot = priorSnapshot,
        _random = random,
        _sessionId = sessionId,
        _config = config,
        _plan = plan,
        _questions = List<IntervalQuestion>.of(plan.questions),
        _session = TrainingSession(
          sessionId: sessionId,
          trainingMode: trainingMode,
          startedAt: startedAt,
          totalQuestions: config.questionCount,
          configSnapshot: config,
          focusPair: focusPair,
          presetId: presetId,
        ),
        _accumulated = StatsSnapshot.empty() {
    // 计划里已经是 drill（二选一强化整组）的题不计入「原始题」集合，但同样可触发
    // 进一步加练——二选一模式靠 focusPair 控制，不会无限递归（见 [_insertExtraDrill]
    // 的去重逻辑）。
  }

  final String _sessionId;
  final TrainingConfig _config;
  final StatsSnapshot _priorSnapshot;
  final math.Random _random;
  final SessionPlan _plan;

  /// 是否二选一强化；其余模式为 `null`。
  final IntervalPair? focusPair;

  /// 触发本组训练的课程预设 id；今日推荐/自由训练为 `null`。
  final String? presetId;

  /// 当前待作答的题目队列（含中途插入的加练题）。
  final List<IntervalQuestion> _questions;

  /// 标记哪些是「加练插题」的下标——加练题答错不再触发新加练，避免无限递归。
  final Set<int> _drillIndices = <int>{};

  /// 已产生的作答流水。
  final List<TrainingAttempt> _attempts = <TrainingAttempt>[];

  /// 本会话内逐题累积的统计（从 [StatsSnapshot.empty] 起，每答一题叠加）。
  StatsSnapshot _accumulated;

  /// 会话运行中的汇总记录。
  TrainingSession _session;

  /// 当前游标：指向下一道**待答**的题。
  int _cursor = 0;

  /// 当前连击数（答对 +1，答错/不确定清零）。
  int _combo = 0;

  /// 本会话最长连击。
  int _maxCombo = 0;

  /// 当前待答的题；已结算或无题时返回 `null`。
  IntervalQuestion? get currentQuestion =>
      _cursor < _questions.length ? _questions[_cursor] : null;

  /// 是否还有题要答。
  bool get hasNext => _cursor < _questions.length;

  /// 会话是否已结算（题目全部答完）。
  bool get isFinished => !hasNext;

  /// 已答（含加练）题数。
  int get completedCount => _session.completedQuestions;

  /// 计划题数（不含加练）。
  int get plannedCount => _session.totalQuestions;

  /// 已插入的加练题数。
  int get extraDrillCount => _session.extraDrillCount;

  /// 完成进度 `[0, 1]`；无穷保护用 [MathUtils.safeDivide]。
  double get progress => MathUtils.safeDivide(
        _session.completedQuestions,
        _session.totalQuestions + _session.extraDrillCount,
      );

  /// 本会话的实时正确率（含不确定计入分母）。
  double get accuracy => _session.accuracy;

  /// 当前连击。
  int get combo => _combo;

  /// 作答流水（不可变视图）。
  List<TrainingAttempt> get attempts =>
      List<TrainingAttempt>.unmodifiable(_attempts);

  /// 题目队列（不可变视图，含加练）。
  List<IntervalQuestion> get questions =>
      List<IntervalQuestion>.unmodifiable(_questions);

  /// 运行中的会话记录。
  TrainingSession get session => _session;

  /// 组卷计划（用于「今日推荐理由」展示）。
  SessionPlan get plan => _plan;

  /// 提交一道题的答案，驱动整条工作流。
  ///
  /// [selectedInterval] 用户所选音程；[isUncertain] 点了「不确定」；[replayCount]
  /// 本题重播次数；[responseDuration] 响应耗时；[now] 作答时刻；[feedbackDwell]
  /// 在反馈页停留时长。返回本次生成的 [TrainingAttempt]。
  ///
  /// 已结算后调用抛 [StateError]——表现层不应在结算后还继续作答。
  TrainingAttempt answer({
    required IntervalId? selectedInterval,
    required bool isUncertain,
    required int replayCount,
    required Duration responseDuration,
    required DateTime now,
    Duration feedbackDwell = Duration.zero,
  }) {
    if (isFinished) {
      throw StateError('SessionRunner.answer 在会话已结算后调用');
    }
    final question = _questions[_cursor];

    // 「不确定」一律视为未选，确保后续统计口径与 TrainingAttempt.isCorrect 一致。
    final selected = isUncertain ? null : selectedInterval;
    final attempt = TrainingAttempt(
      attemptId: IdFactory.attempt(now, _random),
      sessionId: _sessionId,
      questionId: question.questionId,
      correctInterval: question.correctInterval,
      selectedInterval: selected,
      isUncertain: isUncertain,
      replayCount: replayCount,
      responseDuration: responseDuration,
      direction: question.direction,
      timbre: question.timbre,
      rootMode: question.rootMode,
      rootMidiNote: question.rootMidiNote,
      answerMode: _config.answerMode,
      bucket: question.bucket,
      focusPair: question.focusPair,
      feedbackDwell: feedbackDwell,
      createdAt: now,
    );

    _attempts.add(attempt);
    _accumulated = _accumulated.withAttempt(attempt);

    final correct = attempt.isCorrect;
    if (correct) {
      _combo += 1;
      if (_combo > _maxCombo) {
        _maxCombo = _combo;
      }
    } else {
      _combo = 0;
    }

    _session = _session.copyWith(
      completedQuestions: _session.completedQuestions + 1,
      correctCount: _session.correctCount + (correct ? 1 : 0),
      uncertainCount: _session.uncertainCount + (isUncertain ? 1 : 0),
      maxCombo: math.max(_maxCombo, _session.maxCombo),
    );

    // 答错（含不确定）→ 插入二选一加练。加练题本身答错不再递归（见 [_drillIndices]）。
    final isDrillQuestion = _drillIndices.contains(_cursor);
    if (!correct && !isDrillQuestion) {
      _insertExtraDrill(missed: attempt, now: now);
    }

    _cursor += 1;
    if (isFinished) {
      _finish(now);
    }
    return attempt;
  }

  /// 提前结算（用户中途退出）。未结算却要读结算字段时调用。
  void finishNow(DateTime now) {
    if (isFinished) {
      return;
    }
    _cursor = _questions.length;
    _finish(now);
  }

  /// 把本会话的全部作答叠加到「会话前历史」上，得到最新全量统计。
  ///
  /// 这与 `StatsSnapshot.rebuildFromAttempts` 增量叠加的语义一致：先逐条
  /// [StatsSnapshot.withAttempt]，最后 [StatsSnapshot.withSession] 累加会话级字段。
  StatsSnapshot get updatedSnapshot {
    var snapshot = _priorSnapshot;
    for (final attempt in _attempts) {
      snapshot = snapshot.withAttempt(attempt);
    }
    if (_session.isFinished()) {
      snapshot = snapshot.withSession(_session);
    }
    return snapshot;
  }

  /// 章节推进判定（架构 §5.7）。
  ///
  /// 条件：同一 [presetId] 下**最近** [kChapterAdvanceMinSessions] 个**已结算**会话
  /// 的平均正确率 ≥ [kChapterAdvanceAccuracy]，才允许解锁下一章。历史不足直接判否。
  ///
  /// 这是纯函数（只看入参，不读本会话状态），便于在「章节管理」层或服务层独立测试。
  static bool shouldAdvanceChapter(
    List<TrainingSession> recentSessions, {
    required String? presetId,
  }) {
    final scoped = recentSessions
        .where((s) => s.isFinished())
        .where((s) => presetId == null || s.presetId == presetId)
        .toList(growable: false);
    if (scoped.length < kChapterAdvanceMinSessions) {
      return false;
    }
    final tail = scoped.sublist(
      scoped.length - kChapterAdvanceMinSessions,
      scoped.length,
    );
    final sum = tail.fold<double>(0, (acc, s) => acc + s.accuracy);
    final average = MathUtils.safeDivide(sum, tail.length);
    return average >= kChapterAdvanceAccuracy;
  }

  void _insertExtraDrill({
    required TrainingAttempt missed,
    required DateTime now,
  }) {
    final drill = AdaptiveQuestionPlanner.planExtraDrill(
      missed: missed.correctInterval,
      config: _config,
      snapshot: updatedSnapshot,
      random: _random,
      now: now,
      count: kExtraDrillQuestionCount,
    );
    if (drill.isEmpty) {
      return;
    }
    // 插在当前题之后、下一道原始题之前，形成「错 → 当场纠正」的闭环。
    final startIndex = _cursor + 1;
    _questions.insertAll(startIndex, drill);
    for (var i = startIndex; i < startIndex + drill.length; i++) {
      _drillIndices.add(i);
    }
    _session = _session.copyWith(
      extraDrillCount: _session.extraDrillCount + drill.length,
    );
  }

  void _finish(DateTime now) {
    _session = _session.copyWith(finishedAt: now);
  }

  @override
  String toString() => 'SessionRunner($_sessionId, '
      '进度 ${_session.completedQuestions}/${_session.totalQuestions + _session.extraDrillCount}, '
      '正确率 ${(accuracy * 100).toStringAsFixed(1)}%)';
}
