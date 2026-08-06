import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';

/// 设置 DTO（T16）：包装 [AppSettings]。
class SettingsDto {
  /// 创建 DTO。
  const SettingsDto(this.settings);

  /// 包装的设置。
  final AppSettings settings;

  /// 实体类型判别。
  static const String type = 'settings';

  /// 序列化（含 `type` + `schemaVersion`）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'schemaVersion': 1,
        ...settings.toJson(),
      };

  /// 反序列化（顶层 `type`/`schemaVersion` 被 [AppSettings.fromJson] 忽略）。
  factory SettingsDto.fromJson(Map<String, dynamic> json) =>
      SettingsDto(AppSettings.fromJson(json));
}

/// 自由训练配置 DTO（T16）。
class FreeConfigDto {
  /// 创建 DTO。
  const FreeConfigDto(this.config);

  /// 包装的配置。
  final TrainingConfig config;

  /// 实体类型判别。
  static const String type = 'freeConfig';

  /// 序列化。
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'type': type, ...config.toJson()};

  /// 反序列化。
  factory FreeConfigDto.fromJson(Map<String, dynamic> json) =>
      FreeConfigDto(TrainingConfig.fromJson(json));
}

/// 窗口几何 DTO（T16）。
class WindowGeometryDto {
  /// 创建 DTO。
  const WindowGeometryDto(this.geometry);

  /// 包装的几何。
  final WindowGeometry geometry;

  /// 实体类型判别。
  static const String type = 'window';

  /// 序列化。
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'type': type, ...geometry.toJson()};

  /// 反序列化。
  factory WindowGeometryDto.fromJson(Map<String, dynamic> json) =>
      WindowGeometryDto(WindowGeometry.fromJson(json));
}
