import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';

/// 设置仓储接口（架构 §3.5 / T16）。
///
/// 设置项即时持久化；重启后保留。实现见 `data/settings_repository_impl.dart`。
abstract class SettingsRepository {
  /// 加载设置；无记录时返回 [AppSettings.defaults]。
  Future<AppSettings> load();

  /// 原子写入设置。
  Future<void> save(AppSettings settings);

  /// 加载上次自由训练的配置；无记录时返回 [TrainingConfig.defaults]。
  Future<TrainingConfig> loadLastFreeConfig();

  /// 保存自由训练配置（跨会话保留用户的题数/音程选择）。
  Future<void> saveLastFreeConfig(TrainingConfig config);

  /// 加载桌面窗口几何；无记录时返回 `null`。
  Future<WindowGeometry?> loadWindowGeometry();

  /// 保存桌面窗口几何。
  Future<void> saveWindowGeometry(WindowGeometry geometry);
}
