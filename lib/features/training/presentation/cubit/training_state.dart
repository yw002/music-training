import 'package:equatable/equatable.dart';

import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 一次播放的轻量进度快照（架构 §3.4 / §5.6）。
///
/// **纵深防御（防泄露）**：本对象**只携带**音序播放的结构信息（当前在第几音、
/// 音色、位置），**绝不携带**任何 `midiNote` / `frequency` / `pitch` 字段。即使
/// UI 误用它，也不可能把答案画在屏幕上（与 [AudioPlaybackEvent] 的设计一致）。
/// 可视化幅度一律由 `EnvelopeSampler.amplitudeAt` 纯函数按「距起音的毫秒数」算出。
class PlaybackProgress extends Equatable {
  /// 创建播放进度快照。
  const PlaybackProgress({
    required this.playbackId,
    required this.noteIndex,
    required this.timbre,
    required this.position,
    required this.noteDuration,
    this.isFinished = false,
  });

  /// 所属播放 id（每次播放都换新 id）。
  final int playbackId;

  /// 当前发声的音符下标：0=根音，1=目标音，-1=和声同响。
  final int noteIndex;

  /// 正在响的音色（仅用于可视化「风格」，不含音高）。
  final Timbre timbre;

  /// 事件发生时的序列位置。
  final Duration position;

  /// 该音符的时长（供可视化简洁运行）。
  final Duration noteDuration;

  /// 整段序列是否已经结束。
  final bool isFinished;

  /// 整段正在播放中（既不是结束也不是被取消）。
  bool get isActive => !isFinished;

  @override
  List<Object?> get props => <Object?>[
        playbackId,
        noteIndex,
        timbre,
        position,
        noteDuration,
        isFinished,
      ];
}

/// 训练页状态机（架构 §3.5 / T10 验收）。
///
/// 状态流转：`initial → loading → ready → playing → awaitingAnswer → answered
/// → (next) → ready/playing … → finished`。
///
/// **防泄露护栏**：`awaitingAnswer` 及之前的任何状态都**不携带** `correctInterval`
/// / `rootMidiNote` / `targetMidiNote` 等音高信息（见 [IntervalQuestion] 的契约）。
/// 表现层只能读到 `answerOptions` 与 `direction`，答案只在 `answered` 状态才可见。
sealed class TrainingState extends Equatable {
  /// 所有状态的公共构造。
  const TrainingState();
}

/// 尚未开始（页面挂载但未 [TrainingCubit.start]）。
final class TrainingInitial extends TrainingState {
  /// 创建初始态。
  const TrainingInitial();

  @override
  List<Object?> get props => <Object?>[];
}

/// 正在加载历史统计（组卷前必须拿到先验快照）。瞬时态。
final class TrainingLoading extends TrainingState {
  /// 创建加载态。
  const TrainingLoading();

  @override
  List<Object?> get props => <Object?>[];
}

/// 题目已就绪、尚未开始播放的快照字段基类。
///
/// `ready` 与 `awaitingAnswer` 必须让答案区**逐像素一致**（§5.6 golden），因此
/// 两者的公共字段完全一致——差异只在于可视化的「正在播放」状态，而可视化绝不读
/// 答案，故答案区天然相同。
abstract class ActiveQuestionState extends TrainingState {
  const ActiveQuestionState({
    required this.question,
    required this.answerOptions,
    required this.index,
    required this.total,
    required this.combo,
    required this.canReplay,
  });

  /// 当前题目。
  final IntervalQuestion question;

  /// 答案选项（按半音数升序，顺序与正确答案无关，防位置泄露）。
  final List<IntervalId> answerOptions;

  /// 当前题下标（从 0 开始）。
  final int index;

  /// 本组总题数（含加练）。
  final int total;

  /// 当前连击数（来自 [SessionRunner]）。
  final int combo;

  /// 是否允许重播（来自训练配置）。
  final bool canReplay;

  /// 进度 [0, 1]。
  double get progress => total <= 0 ? 0.0 : (index / total).clamp(0.0, 1.0);

  @override
  List<Object?> get props => <Object?>[
        question,
        answerOptions,
        index,
        total,
        combo,
        canReplay,
      ];
}

/// 题目就绪，等待首次自动播放（仅作状态机起点，UI 与 [TrainingPlaying] 一致）。
final class TrainingReady extends ActiveQuestionState {
  /// 创建就绪态。
  const TrainingReady({
    required super.question,
    required super.answerOptions,
    required super.index,
    required super.total,
    required super.combo,
    required super.canReplay,
  });
}

/// 正在播放当前题目。
final class TrainingPlaying extends ActiveQuestionState {
  /// 创建播放态。
  const TrainingPlaying({
    required super.question,
    required super.answerOptions,
    required super.index,
    required super.total,
    required super.combo,
    required super.canReplay,
    required this.playback,
  });

  /// 当前播放进度（仅结构信息，不含音高）。
  final PlaybackProgress playback;

  @override
  List<Object?> get props => <Object?>[...super.props, playback];
}

/// 播放结束，等待用户作答。
final class TrainingAwaitingAnswer extends ActiveQuestionState {
  /// 创建等待作答态。
  const TrainingAwaitingAnswer({
    required super.question,
    required super.answerOptions,
    required super.index,
    required super.total,
    required super.combo,
    required super.canReplay,
    required this.replayCount,
    this.lastPlayback,
  });

  /// 本题已重播次数（不含首次自动播放）。
  final int replayCount;

  /// 最近一次播放进度（供可视化做收尾衰减）。
  final PlaybackProgress? lastPlayback;

  @override
  List<Object?> get props => <Object?>[
        ...super.props,
        replayCount,
        lastPlayback,
      ];
}

/// 已提交答案，展示反馈。
final class TrainingAnswered extends ActiveQuestionState {
  /// 创建已作答态。
  const TrainingAnswered({
    required super.question,
    required super.answerOptions,
    required super.index,
    required super.total,
    required super.combo,
    required super.canReplay,
    required this.attempt,
    required this.isLast,
    required this.chapterAdvanced,
    required this.session,
  });

  /// 本次作答记录（含正确答案，可在反馈区展示）。
  final TrainingAttempt attempt;

  /// 是否为本组最后一题（答完即为结算）。
  final bool isLast;

  /// 本组结束后是否触发章节推进（§5.7）。
  final bool chapterAdvanced;

  /// 进行中的会话记录（实时正确率等供结算提示）。
  final TrainingSession session;

  /// 是否答对。
  bool get isCorrect => attempt.isCorrect;

  /// 是否点了「不确定」。
  bool get isUncertain => attempt.isUncertain;

  /// 用户所选音程（不确定为 `null`）。
  IntervalId? get selectedInterval => attempt.selectedInterval;

  @override
  List<Object?> get props => <Object?>[
        ...super.props,
        attempt,
        isLast,
        chapterAdvanced,
        session,
      ];
}

/// 整组结束，进入结算。
final class TrainingFinished extends TrainingState {
  /// 创建结算态。
  const TrainingFinished({
    required this.session,
    required this.snapshot,
    required this.chapterAdvanced,
    this.chapterName,
  });

  /// 已结算的会话记录。
  final TrainingSession session;

  /// 最新的全量统计快照。
  final StatsSnapshot snapshot;

  /// 是否触发了章节推进。
  final bool chapterAdvanced;

  /// 被解锁的章节名（若为 `null` 表示无章节语义或仅常规推进）。
  final String? chapterName;

  @override
  List<Object?> get props => <Object?>[
        session,
        snapshot,
        chapterAdvanced,
        chapterName,
      ];
}
