import 'dart:io';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/storage/json_file_store.dart';
import 'package:interval_ear/features/training/data/settings_dto.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';

/// 设置仓储实现（T16）。
///
/// 各项设置走 `JsonFileStore` 的原子写；读不到时降级到默认值，绝不抛异常。
class SettingsRepositoryImpl implements SettingsRepository {
  /// 创建实现（[dataDir] 为设置所在目录）。
  SettingsRepositoryImpl({required Directory dataDir})
      : _store = JsonFileStore(dir: dataDir);

  final JsonFileStore _store;

  static const String _freeConfigName = 'free_config.json';
  static const String _windowName = 'window.json';

  @override
  Future<AppSettings> load() async {
    final json = await _store.read(AppConfig.settingsFileName);
    if (json == null) {
      return AppSettings.defaults;
    }
    try {
      return AppSettings.fromJson(json);
    } on Object {
      return AppSettings.defaults;
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _store.writeAtomic(
      AppConfig.settingsFileName,
      SettingsDto(settings).toJson(),
    );
  }

  @override
  Future<TrainingConfig> loadLastFreeConfig() async {
    final json = await _store.read(_freeConfigName);
    if (json == null) {
      return TrainingConfig.defaults;
    }
    try {
      return TrainingConfig.fromJson(json);
    } on Object {
      return TrainingConfig.defaults;
    }
  }

  @override
  Future<void> saveLastFreeConfig(TrainingConfig config) async {
    await _store.writeAtomic(_freeConfigName, FreeConfigDto(config).toJson());
  }

  @override
  Future<WindowGeometry?> loadWindowGeometry() async {
    final json = await _store.read(_windowName);
    if (json == null) {
      return null;
    }
    try {
      return WindowGeometry.fromJson(json);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveWindowGeometry(WindowGeometry geometry) async {
    await _store.writeAtomic(_windowName, WindowGeometryDto(geometry).toJson());
  }
}
