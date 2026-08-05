import 'package:equatable/equatable.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/schema_version.dart';

/// 一次作答记录（架构 §3.1）。这是 JSONL 里唯一逐条追加的实体，
/// 所有统计都能从作答流水**完全重算**（`rebuildFromAttempts`）。
///
/// **「不确定」的语义（原规范）**：`isUncertain == true` 表示用户主动承认没听出来。
/// 它 **不算普通错误猜测**——不进混淆矩阵、不清零连击。两处口径要分清：
/// - 掌握度（§5.1）：从有效作答数 `n` 中**剔除**，因此不确定既不加分也不扣分，
///   只是让 `n` 涨不上去 → 置信度低 → mastery 低。刷「不确定」刷不出掌握度。
/// - 会话正确率（结算页）：按「未答对」计入分母，用户看到的是真实完成度。
class TrainingAttempt extends Equatable {
  /// 创建一条作答记录。
  const TrainingAttempt({
    required this.attemptId,
    required this.sessionId,
    required this.questionId,
    required this.correctInterval,
    required this.selectedInterval,
    required this.isUncertain,
    required this.replayCount,
    required this.responseDuration,
    required this.direction,
    required this.timbre,
    required this.rootMode,
    required this.rootMidiNote,
    required this.answerMode,
    required this.createdAt,
    this.bucket = QuestionBucket.randomProbe,
    this.focusPair,
    this.feedbackDwell = Duration.zero,
    this.schemaVersion = kDomainSchemaVersion,
  });

  /// 作答唯一 ID。
  final String attemptId;

  /// 所属会话 ID。
  final String sessionId;

  /// 对应题目 ID。
  final String questionId;

  /// 正确音程。
  final IntervalId correctInterval;

  /// 用户所选音程；点「不确定」或超时未答时为 `null`。
  final IntervalId? selectedInterval;

  /// 是否点了「不确定」。
  final bool isUncertain;

  /// 本题重播次数（不含首次自动播放）。
  final int replayCount;

  /// 从题目就绪到提交答案的耗时。
  final Duration responseDuration;

  /// 播放方向。
  final PlaybackDirection direction;

  /// 音色。
  final Timbre timbre;

  /// 根音策略。
  final RootMode rootMode;

  /// 根音 MIDI 号。
  final int rootMidiNote;

  /// 答题选项策略。
  final AnswerMode answerMode;

  /// 题目来源桶。
  final QuestionBucket bucket;

  /// 二选一强化时本题所属的音程对（[IntervalPair.key] 形式，如 `'m6|M6'`）。
  ///
  /// **为什么必须落在作答上而不是只落在题目上**：`PairStatistics` 要能从
  /// attempts.jsonl **完全重算**（架构 §3.2 的 `rebuildFromAttempts` 契约）。
  /// 答错时虽然能从「正确音程 + 所选音程」反推出对，但**答对时推不出干扰项**，
  /// 那样重算出来的音程对统计会只剩错题，正确率恒为 0。
  final String? focusPair;

  /// 在反馈页停留的时长（用于判断用户是否真的看了对比结果）。
  final Duration feedbackDwell;

  /// 作答时刻。
  final DateTime createdAt;

  /// 落盘 schema 版本。
  final int schemaVersion;

  /// 是否答对。「不确定」一律记为不正确。
  bool get isCorrect => !isUncertain && selectedInterval == correctInterval;

  /// 是否「首播即答对」（没有重播就答对）。这是比正确率更硬的听辨能力指标。
  bool firstPlayCorrect() => isCorrect && replayCount == 0;

  /// 是否应计入混淆矩阵：必须有明确选择，且不是「不确定」。
  ///
  /// 注意答对（对角线）**也要**进矩阵——报告页要用 success 色系画对角线。
  bool get countsTowardConfusion => !isUncertain && selectedInterval != null;

  /// 响应耗时的毫秒数。
  int get responseMs => responseDuration.inMilliseconds;

  /// 复制并覆盖部分字段。[selectedInterval] 用 [clearSelected] 显式清空。
  TrainingAttempt copyWith({
    String? attemptId,
    String? sessionId,
    String? questionId,
    IntervalId? correctInterval,
    IntervalId? selectedInterval,
    bool clearSelected = false,
    bool? isUncertain,
    int? replayCount,
    Duration? responseDuration,
    PlaybackDirection? direction,
    Timbre? timbre,
    RootMode? rootMode,
    int? rootMidiNote,
    AnswerMode? answerMode,
    QuestionBucket? bucket,
    String? focusPair,
    bool clearFocusPair = false,
    Duration? feedbackDwell,
    DateTime? createdAt,
    int? schemaVersion,
  }) =>
      TrainingAttempt(
        attemptId: attemptId ?? this.attemptId,
        sessionId: sessionId ?? this.sessionId,
        questionId: questionId ?? this.questionId,
        correctInterval: correctInterval ?? this.correctInterval,
        selectedInterval:
            clearSelected ? null : (selectedInterval ?? this.selectedInterval),
        isUncertain: isUncertain ?? this.isUncertain,
        replayCount: replayCount ?? this.replayCount,
        responseDuration: responseDuration ?? this.responseDuration,
        direction: direction ?? this.direction,
        timbre: timbre ?? this.timbre,
        rootMode: rootMode ?? this.rootMode,
        rootMidiNote: rootMidiNote ?? this.rootMidiNote,
        answerMode: answerMode ?? this.answerMode,
        bucket: bucket ?? this.bucket,
        focusPair: clearFocusPair ? null : (focusPair ?? this.focusPair),
        feedbackDwell: feedbackDwell ?? this.feedbackDwell,
        createdAt: createdAt ?? this.createdAt,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  /// 序列化。`isCorrect` 不落盘——它是 [selectedInterval] 与 [isUncertain] 的
  /// 派生量，落盘会带来「两个真相」的一致性风险。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'attemptId': attemptId,
        'sessionId': sessionId,
        'questionId': questionId,
        'correctInterval': correctInterval.storageId,
        if (selectedInterval != null)
          'selectedInterval': selectedInterval!.storageId,
        'isUncertain': isUncertain,
        'replayCount': replayCount,
        'responseMs': responseDuration.inMilliseconds,
        'direction': direction.storageId,
        'timbre': timbre.storageId,
        'rootMode': rootMode.storageId,
        'rootMidiNote': rootMidiNote,
        'answerMode': answerMode.storageId,
        'bucket': bucket.storageId,
        if (focusPair != null) 'focusPair': focusPair,
        'feedbackDwellMs': feedbackDwell.inMilliseconds,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  /// 反序列化。
  factory TrainingAttempt.fromJson(Map<String, dynamic> json) =>
      TrainingAttempt(
        attemptId: json['attemptId'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        questionId: json['questionId'] as String? ?? '',
        correctInterval: IntervalId.fromStorageId(json['correctInterval']),
        selectedInterval:
            IntervalId.tryFromStorageId(json['selectedInterval']),
        isUncertain: json['isUncertain'] as bool? ?? false,
        replayCount: _readInt(json['replayCount']),
        responseDuration: Duration(milliseconds: _readInt(json['responseMs'])),
        direction: PlaybackDirection.fromStorageId(json['direction']),
        timbre: Timbre.fromStorageId(json['timbre']),
        rootMode: RootMode.fromStorageId(json['rootMode']),
        rootMidiNote: _readInt(json['rootMidiNote']),
        answerMode: AnswerMode.fromStorageId(json['answerMode']),
        bucket: QuestionBucket.fromStorageId(json['bucket']),
        focusPair: json['focusPair'] as String?,
        feedbackDwell:
            Duration(milliseconds: _readInt(json['feedbackDwellMs'])),
        createdAt: _readTime(json['createdAt']),
        schemaVersion: readSchemaVersion(json),
      );

  static int _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return 0;
  }

  static DateTime _readTime(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  @override
  List<Object?> get props => <Object?>[
        attemptId,
        sessionId,
        questionId,
        correctInterval,
        selectedInterval,
        isUncertain,
        replayCount,
        responseDuration,
        direction,
        timbre,
        rootMode,
        rootMidiNote,
        answerMode,
        bucket,
        focusPair,
        feedbackDwell,
        createdAt.toUtc(),
        schemaVersion,
      ];

  @override
  String toString() => 'TrainingAttempt($attemptId, '
      '${correctInterval.storageId} -> '
      '${selectedInterval?.storageId ?? (isUncertain ? "uncertain" : "none")}, '
      'correct=$isCorrect)';
}
