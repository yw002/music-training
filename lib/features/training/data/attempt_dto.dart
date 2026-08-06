import 'package:interval_ear/features/training/domain/models/training_attempt.dart';

/// 作答记录 DTO（T16）。
///
/// 在领域模型的序列化之上加一个 `type` 判别字段，让 JSONL 每一行自描述——
/// 未来若要混存多种实体，读取端能按 `type` 分流，而不必猜「这行是 attempt 还是
/// session」。
class AttemptDto {
  /// 创建 DTO。
  const AttemptDto(this.attempt);

  /// 包装的作答。
  final TrainingAttempt attempt;

  /// 实体类型判别。
  static const String type = 'attempt';

  /// 序列化（含 `type`）。
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'type': type, ...attempt.toJson()};

  /// 反序列化。行里的 `type` 字段会被 [TrainingAttempt.fromJson] 安全忽略。
  factory AttemptDto.fromJson(Map<String, dynamic> json) =>
      AttemptDto(TrainingAttempt.fromJson(json));
}
