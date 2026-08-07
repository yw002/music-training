import 'package:equatable/equatable.dart';

import 'package:interval_ear/features/training/domain/models/training_config.dart';

/// 自由训练配置页状态（架构 §2.4 / T19）。
///
/// 持有当前正在编辑的 [TrainingConfig]，以及最近一次校验结果 [validation]
///（[ValidationResult.valid] 表示通过）。配置每次变更都会清空校验结果，避免
/// 旧的错误提示残留。
class FreeTrainingState extends Equatable {
  /// 创建设置态。
  const FreeTrainingState({
    required this.config,
    this.validation = const ValidationResult.valid(),
  });

  /// 当前编辑中的配置。
  final TrainingConfig config;

  /// 最近一次校验结果。
  final ValidationResult validation;

  /// 是否通过校验。
  bool get isValid => validation.isValid;

  /// 复制并覆盖部分字段。
  FreeTrainingState copyWith({
    TrainingConfig? config,
    ValidationResult? validation,
  }) =>
      FreeTrainingState(
        config: config ?? this.config,
        validation: validation ?? this.validation,
      );

  @override
  List<Object?> get props => <Object?>[config, validation];
}
