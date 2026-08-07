import 'package:equatable/equatable.dart';
import 'package:interval_ear/core/utils/math_utils.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/schema_version.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';

/// 一组训练的汇总记录（架构 §3.1）。
///
/// 这是**派生实体**：所有字段都能从该会话的 `TrainingAttempt` 流水重算。
/// 落盘它只是为了让「结算页 / 历史列表」不必每次扫全量流水。
class TrainingSession extends Equatable {
  /// 创建一条会话记录。
  const TrainingSession({
    required this.sessionId,
    required this.trainingMode,
    required this.startedAt,
    required this.totalQuestions,
    required this.configSnapshot,
    this.finishedAt,
    this.completedQuestions = 0,
    this.correctCount = 0,
    this.uncertainCount = 0,
    this.extraDrillCount = 0,
    this.maxCombo = 0,
    this.focusPair,
    this.presetId,
    this.mistakes = const <TrainingAttempt>[],
    this.schemaVersion = kDomainSchemaVersion,
  });

  /// 会话唯一 ID。
  final String sessionId;

  /// 训练模式。
  final TrainingMode trainingMode;

  /// 开始时刻。
  final DateTime startedAt;

  /// 结束时刻；中途退出且未结算时为 `null`。
  final DateTime? finishedAt;

  /// 计划题数。
  final int totalQuestions;

  /// 已完成题数（含加练题）。
  final int completedQuestions;

  /// 答对题数。
  final int correctCount;

  /// 「不确定」次数。
  final int uncertainCount;

  /// 本组中途插入的加练题数。
  final int extraDrillCount;

  /// 本组最长连击。
  final int maxCombo;

  /// 配置快照（组内不可变）。
  final TrainingConfig configSnapshot;

  /// 二选一强化的焦点音程对；其他模式为 `null`。
  final IntervalPair? focusPair;

  /// 触发本组训练的课程预设 id；今日推荐 / 自由训练为 `null`。
  ///
  /// 架构 §5.7 的 `shouldAdvanceChapter` 需要按预设过滤最近会话，类图里漏了
  /// 这个字段，这里补上。
  final String? presetId;

  /// 本组答错的作答（含「不确定」），供结算页错题清单回放对比。
  ///
  /// 与 `StatsSnapshot` 互为独立：这里是「这一组」的错题快照，便于结算页直接
  /// 复用 [FeedbackController] 做对比播放，而不必再去流水里捞。向后兼容：旧
  /// 落盘数据缺该字段时按空列表处理。
  final List<TrainingAttempt> mistakes;

  /// 落盘 schema 版本。
  final int schemaVersion;

  /// 是否已结算。
  bool isFinished() => finishedAt != null;

  /// 正确率 `[0, 1]`；一题未答时为 0（不产生 NaN）。
  double get accuracy => MathUtils.safeDivide(correctCount, completedQuestions);

  /// 训练时长；未结算时为 `null`。
  Duration? get duration => finishedAt?.difference(startedAt);

  /// 剩余题数（不小于 0）。
  int get remainingQuestions {
    final remaining = totalQuestions + extraDrillCount - completedQuestions;
    return remaining < 0 ? 0 : remaining;
  }

  /// 复制并覆盖部分字段。
  TrainingSession copyWith({
    String? sessionId,
    TrainingMode? trainingMode,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    int? totalQuestions,
    int? completedQuestions,
    int? correctCount,
    int? uncertainCount,
    int? extraDrillCount,
    int? maxCombo,
    TrainingConfig? configSnapshot,
    IntervalPair? focusPair,
    bool clearFocusPair = false,
    String? presetId,
    bool clearPresetId = false,
    List<TrainingAttempt>? mistakes,
    int? schemaVersion,
  }) =>
      TrainingSession(
        sessionId: sessionId ?? this.sessionId,
        trainingMode: trainingMode ?? this.trainingMode,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
        totalQuestions: totalQuestions ?? this.totalQuestions,
        completedQuestions: completedQuestions ?? this.completedQuestions,
        correctCount: correctCount ?? this.correctCount,
        uncertainCount: uncertainCount ?? this.uncertainCount,
        extraDrillCount: extraDrillCount ?? this.extraDrillCount,
        maxCombo: maxCombo ?? this.maxCombo,
        configSnapshot: configSnapshot ?? this.configSnapshot,
        focusPair: clearFocusPair ? null : (focusPair ?? this.focusPair),
        presetId: clearPresetId ? null : (presetId ?? this.presetId),
        mistakes: mistakes ?? this.mistakes,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  /// 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'sessionId': sessionId,
        'trainingMode': trainingMode.storageId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (finishedAt != null)
          'finishedAt': finishedAt!.toUtc().toIso8601String(),
        'totalQuestions': totalQuestions,
        'completedQuestions': completedQuestions,
        'correctCount': correctCount,
        'uncertainCount': uncertainCount,
        'extraDrillCount': extraDrillCount,
        'maxCombo': maxCombo,
        'configSnapshot': configSnapshot.toJson(),
        if (focusPair != null) 'focusPair': focusPair!.key(),
        if (presetId != null) 'presetId': presetId,
        'mistakes': mistakes.map((a) => a.toJson()).toList(growable: false),
      };

  /// 反序列化。
  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['configSnapshot'];
    return TrainingSession(
      sessionId: json['sessionId'] as String? ?? '',
      trainingMode: TrainingMode.fromStorageId(json['trainingMode']),
      startedAt: _readTime(json['startedAt']),
      finishedAt: _readNullableTime(json['finishedAt']),
      totalQuestions: _readInt(json['totalQuestions']),
      completedQuestions: _readInt(json['completedQuestions']),
      correctCount: _readInt(json['correctCount']),
      uncertainCount: _readInt(json['uncertainCount']),
      extraDrillCount: _readInt(json['extraDrillCount']),
      maxCombo: _readInt(json['maxCombo']),
      configSnapshot: rawConfig is Map<String, dynamic>
          ? TrainingConfig.fromJson(rawConfig)
          : TrainingConfig.defaults,
      focusPair: IntervalPair.tryFromKey(json['focusPair'] as String? ?? ''),
      presetId: json['presetId'] as String?,
      mistakes: _readMistakes(json['mistakes']),
      schemaVersion: readSchemaVersion(json),
    );
  }

  static int _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return 0;
  }

  static DateTime _readTime(Object? raw) =>
      _readNullableTime(raw) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static DateTime? _readNullableTime(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc();
    }
    return null;
  }

  static List<TrainingAttempt> _readMistakes(Object? raw) {
    if (raw is! List) {
      return const <TrainingAttempt>[];
    }
    final result = <TrainingAttempt>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        result.add(TrainingAttempt.fromJson(item));
      }
    }
    return List<TrainingAttempt>.unmodifiable(result);
  }

  @override
  List<Object?> get props => <Object?>[
        sessionId,
        trainingMode,
        startedAt.toUtc(),
        finishedAt?.toUtc(),
        totalQuestions,
        completedQuestions,
        correctCount,
        uncertainCount,
        extraDrillCount,
        maxCombo,
        configSnapshot,
        focusPair,
        presetId,
        mistakes,
        schemaVersion,
      ];

  @override
  String toString() => 'TrainingSession($sessionId, '
      '${trainingMode.storageId}, $correctCount/$completedQuestions)';
}
