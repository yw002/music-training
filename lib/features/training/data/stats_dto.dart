import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 统计快照 DTO（T16）。
///
/// `stats.json` 的顶层封装：带 `type` 与 `schemaVersion`，内容委托
/// [StatsSnapshot] 自身序列化。
class StatsDto {
  /// 创建 DTO。
  const StatsDto(this.snapshot);

  /// 包装的统计快照。
  final StatsSnapshot snapshot;

  /// 实体类型判别。
  static const String type = 'stats';

  /// 序列化（含 `type` + `schemaVersion`）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'schemaVersion': snapshot.schemaVersion,
        ...snapshot.toJson(),
      };

  /// 反序列化。
  factory StatsDto.fromJson(Map<String, dynamic> json) =>
      StatsDto(StatsSnapshot.fromJson(json));
}
