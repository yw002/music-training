import 'package:equatable/equatable.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';

/// 混淆矩阵中的一格：「实际是 [actual]，用户选了 [selected]，共 [count] 次」。
class ConfusionEntry extends Equatable {
  /// 创建一格。
  const ConfusionEntry({
    required this.actual,
    required this.selected,
    required this.count,
  });

  /// 题目的正确音程。
  final IntervalId actual;

  /// 用户选择的音程。
  final IntervalId selected;

  /// 出现次数。
  final int count;

  /// 是否落在对角线（即答对）。
  bool get isDiagonal => actual == selected;

  /// 两者的半音距离。混淆排序在次数相同时用它做次级键：距离近的更值得先练。
  int get semitoneDistance => actual.semitoneDistanceTo(selected);

  /// 转成规范化音程对（丢弃方向信息）。
  IntervalPair toPair() => IntervalPair(actual, selected).normalized();

  /// 复制并覆盖部分字段。
  ConfusionEntry copyWith({
    IntervalId? actual,
    IntervalId? selected,
    int? count,
  }) =>
      ConfusionEntry(
        actual: actual ?? this.actual,
        selected: selected ?? this.selected,
        count: count ?? this.count,
      );

  /// 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'actual': actual.storageId,
        'selected': selected.storageId,
        'count': count,
      };

  /// 反序列化。
  factory ConfusionEntry.fromJson(Map<String, dynamic> json) => ConfusionEntry(
        actual: IntervalId.fromStorageId(json['actual']),
        selected: IntervalId.fromStorageId(json['selected']),
        count: json['count'] is num ? (json['count'] as num).toInt() : 0,
      );

  @override
  List<Object?> get props => <Object?>[actual, selected, count];

  @override
  String toString() =>
      'ConfusionEntry(${actual.storageId}->${selected.storageId}: $count)';
}
