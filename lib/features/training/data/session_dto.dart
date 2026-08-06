import 'package:interval_ear/features/training/domain/models/training_session.dart';

/// 会话记录 DTO（T16）。
///
/// 与 [AttemptDto] 对称，给 JSONL 行加 `type` 判别字段。
class SessionDto {
  /// 创建 DTO。
  const SessionDto(this.session);

  /// 包装的会话。
  final TrainingSession session;

  /// 实体类型判别。
  static const String type = 'session';

  /// 序列化（含 `type`）。
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'type': type, ...session.toJson()};

  /// 反序列化。
  factory SessionDto.fromJson(Map<String, dynamic> json) =>
      SessionDto(TrainingSession.fromJson(json));
}
