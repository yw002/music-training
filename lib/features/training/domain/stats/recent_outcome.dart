import 'package:equatable/equatable.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';

/// 一条精简的近期作答结果（架构 §3.2）。
///
/// 与 `TrainingAttempt` 的分工：`TrainingAttempt` 是**全量流水**（落 JSONL，
/// 可能几万条），[RecentOutcome] 是**滚动窗口**（落 stats.json，只留最近
/// 若干条），用于首页「最近表现」和掌握度的近期项。只保留计算所需的 5 个字段，
/// 让快照文件保持在几十 KB 量级。
class RecentOutcome extends Equatable {
  /// 创建一条近期结果。
  const RecentOutcome({
    required this.correctInterval,
    required this.selectedInterval,
    required this.isCorrect,
    required this.isUncertain,
    required this.at,
  });

  /// 由一条作答记录构造。
  factory RecentOutcome.fromAttempt(TrainingAttempt attempt) => RecentOutcome(
        correctInterval: attempt.correctInterval,
        selectedInterval: attempt.selectedInterval,
        isCorrect: attempt.isCorrect,
        isUncertain: attempt.isUncertain,
        at: attempt.createdAt,
      );

  /// 正确音程。
  final IntervalId correctInterval;

  /// 用户所选；「不确定」或未答为 `null`。
  final IntervalId? selectedInterval;

  /// 是否答对。
  final bool isCorrect;

  /// 是否「不确定」。
  final bool isUncertain;

  /// 作答时刻。
  final DateTime at;

  /// 是否计入掌握度的有效样本（「不确定」不计）。
  bool get isEffective => !isUncertain;

  /// 复制并覆盖部分字段。
  RecentOutcome copyWith({
    IntervalId? correctInterval,
    IntervalId? selectedInterval,
    bool clearSelected = false,
    bool? isCorrect,
    bool? isUncertain,
    DateTime? at,
  }) =>
      RecentOutcome(
        correctInterval: correctInterval ?? this.correctInterval,
        selectedInterval:
            clearSelected ? null : (selectedInterval ?? this.selectedInterval),
        isCorrect: isCorrect ?? this.isCorrect,
        isUncertain: isUncertain ?? this.isUncertain,
        at: at ?? this.at,
      );

  /// 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'a': correctInterval.storageId,
        if (selectedInterval != null) 's': selectedInterval!.storageId,
        'ok': isCorrect,
        'un': isUncertain,
        'at': at.toUtc().toIso8601String(),
      };

  /// 反序列化。
  factory RecentOutcome.fromJson(Map<String, dynamic> json) => RecentOutcome(
        correctInterval: IntervalId.fromStorageId(json['a']),
        selectedInterval: IntervalId.tryFromStorageId(json['s']),
        isCorrect: json['ok'] as bool? ?? false,
        isUncertain: json['un'] as bool? ?? false,
        at: _readTime(json['at']),
      );

  static DateTime _readTime(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  @override
  List<Object?> get props => <Object?>[
        correctInterval,
        selectedInterval,
        isCorrect,
        isUncertain,
        at.toUtc(),
      ];

  @override
  String toString() => 'RecentOutcome(${correctInterval.storageId}, '
      'ok=$isCorrect, uncertain=$isUncertain)';
}
