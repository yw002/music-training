import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_state.dart';

/// 训练页状态机所处的阶段（UI 据此决定渲染分支）。
enum TrainingPhase {
  /// 初始。
  initial,

  /// 加载历史统计。
  loading,

  /// 题目就绪，未播放。
  ready,

  /// 正在播放。
  playing,

  /// 等待作答。
  awaiting,

  /// 已作答，展示反馈。
  answered,

  /// 整组结束。
  finished,
}

/// 单个答案选项的展示数据。
///
/// **防泄露护栏**：作答前 [isCorrect] / [isSelected] 一律为 `false`；只有进入
/// [TrainingAnswered] 后，UI 才能据此给「正确项 / 用户所选」上色。此处**不**携带
/// 任何音高数值，只携带音程的展示元数据（名字、半音数、形状）。
class AnswerOptionView {
  /// 创建答案选项视图。
  const AnswerOptionView({
    required this.id,
    required this.name,
    required this.shorthand,
    required this.semitones,
    this.isCorrect = false,
    this.isSelected = false,
  });

  /// 音程 id。
  final IntervalId id;

  /// 中文名（如 纯一度）。
  final String name;

  /// 英文简称（如 P1）。
  final String shorthand;

  /// 半音数。
  final int semitones;

  /// 是否为正确答案（仅 [TrainingAnswered] 为真）。
  final bool isCorrect;

  /// 是否为用户所选（仅 [TrainingAnswered] 为真）。
  final bool isSelected;

  /// 是否「用户选错」（selected 且非 correct）。
  bool get isWrongSelected => isSelected && !isCorrect;
}

/// 训练页视图模型（架构 §3.5 / T10）。
///
/// 纯函数式的「状态 → 展示数据」映射层，让 [TrainingPage] 保持极薄。**不**做任何
/// 副作用、不读音频、不碰存储；只从 [TrainingState] 派生 UI 需要的字符串与列表。
class TrainingViewModel {
  /// 由当前状态构造视图模型。
  factory TrainingViewModel.from(
    TrainingState state, {
    bool showIntervalShorthand = false,
  }) =>
      TrainingViewModel._(state, showIntervalShorthand);

  const TrainingViewModel._(this._state, this._showIntervalShorthand);

  final TrainingState _state;
  final bool _showIntervalShorthand;

  /// 当前阶段。
  TrainingPhase get phase {
    final s = _state;
    if (s is TrainingInitial) return TrainingPhase.initial;
    if (s is TrainingLoading) return TrainingPhase.loading;
    if (s is TrainingReady) return TrainingPhase.ready;
    if (s is TrainingPlaying) return TrainingPhase.playing;
    if (s is TrainingAwaitingAnswer) return TrainingPhase.awaiting;
    if (s is TrainingAnswered) return TrainingPhase.answered;
    return TrainingPhase.finished;
  }

  /// 当前题目（finished 为 `null`）。
  IntervalQuestionOrNull get question {
    final s = _state;
    if (s is ActiveQuestionState) return s.question;
    return null;
  }

  /// 进度文案：第 3 / 20 题。
  String get progressLabel {
    final s = _state;
    if (s is ActiveQuestionState) {
      return AppStrings.training.questionProgress(s.index + 1, s.total);
    }
    if (s is TrainingFinished) {
      return AppStrings.training.questionProgress(
        s.session.totalQuestions,
        s.session.totalQuestions,
      );
    }
    return '';
  }

  /// 作答引导文案。
  String get promptLabel {
    final s = _state;
    if (s is ActiveQuestionState && s.question.isBinary) {
      return AppStrings.training.binaryPrompt;
    }
    return AppStrings.training.prompt;
  }

  /// 连击文案（>0 才非空）。
  String get comboLabel {
    final s = _state;
    final combo = s is ActiveQuestionState ? s.combo : 0;
    return combo > 0 ? AppStrings.training.comboCount(combo) : '';
  }

  /// 当前连击数。
  int get combo => _state is ActiveQuestionState ? _state.combo : 0;

  /// 是否允许重播。
  bool get canReplay => _state is ActiveQuestionState && _state.canReplay;

  /// 本题重播次数（仅 awaiting）。
  int get replayCount {
    final s = _state;
    return s is TrainingAwaitingAnswer ? s.replayCount : 0;
  }

  /// 是否处于播放中。
  bool get isPlaying => _state is TrainingPlaying;

  /// 是否可作答（awaiting）。
  bool get canAnswer => _state is TrainingAwaitingAnswer;

  /// 当前播放进度（供可视化）。
  PlaybackProgress? get playback {
    final s = _state;
    if (s is TrainingPlaying) return s.playback;
    if (s is TrainingAwaitingAnswer) return s.lastPlayback;
    return null;
  }

  /// 答案选项展示列表。
  List<AnswerOptionView> get options {
    final s = _state;
    if (s is! ActiveQuestionState) {
      return const <AnswerOptionView>[];
    }
    final answered = s is TrainingAnswered ? s : null;
    final correctId = answered?.attempt.correctInterval;
    final selectedId = answered?.attempt.selectedInterval;
    return s.answerOptions.map((id) {
      return AnswerOptionView(
        id: id,
        name: IntervalCatalog.nameOf(id),
        shorthand:
            _showIntervalShorthand ? IntervalCatalog.shorthandOf(id) : '',
        semitones: id.semitones,
        isCorrect: answered != null && id == correctId,
        isSelected: answered != null && id == selectedId,
      );
    }).toList(growable: false);
  }

  /// 是否展示反馈区。
  bool get showFeedback => _state is TrainingAnswered;

  /// 反馈主文案。
  String get feedbackLabel {
    final s = _state;
    if (s is! TrainingAnswered) return '';
    if (s.isUncertain) return AppStrings.feedback.uncertain;
    return s.isCorrect
        ? AppStrings.feedback.correct
        : AppStrings.feedback.wrong;
  }

  /// 反馈语义：success / warning(uncertain) / error。
  FeedbackTone get feedbackTone {
    final s = _state;
    if (s is! TrainingAnswered) return FeedbackTone.none;
    if (s.isUncertain) return FeedbackTone.neutral;
    return s.isCorrect ? FeedbackTone.positive : FeedbackTone.negative;
  }

  /// 是否为本组最后一题。
  bool get isLast {
    final s = _state;
    return s is TrainingAnswered && s.isLast;
  }

  /// 是否触发了章节推进。
  bool get chapterAdvanced =>
      _state is TrainingFinished && _state.chapterAdvanced;
}

/// 题目或 `null` 的轻量包装（避免在视图模型里用 `?` 散布）。
typedef IntervalQuestionOrNull = IntervalQuestion?;

/// 反馈语气。
enum FeedbackTone {
  /// 无。
  none,

  /// 正面（答对）。
  positive,

  /// 中性（不确定）。
  neutral,

  /// 负面（答错）。
  negative,
}
