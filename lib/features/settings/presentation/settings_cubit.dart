import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/features/settings/presentation/settings_state.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';

/// 应用级设置状态源（T17，架构 §1.2）。
///
/// 持有 [AppSettings]，所有变更走 [update] → [SettingsRepository.save] → 落盘，
/// 并 emit [SettingsLoaded] 驱动全局主题/动效即时刷新。生命周期与 App 等长，
/// 由 [AppDependencies] 以单例形式持有。
class SettingsCubit extends Cubit<SettingsState> {
  /// 创建设置 Cubit。
  SettingsCubit({required SettingsRepository repository})
      : _repository = repository,
        super(const SettingsInitial());

  final SettingsRepository _repository;

  /// 当前生效设置；未加载完成前返回 [AppSettings.defaults]。
  AppSettings get current => switch (state) {
        SettingsLoaded(:final settings) => settings,
        _ => AppSettings.defaults,
      };

  /// 加载已保存设置（无记录则为默认值）。构造后由 [AppDependencies] 调用。
  Future<void> load() async {
    final AppSettings settings = await _repository.load();
    emit(SettingsLoaded(settings));
  }

  /// 应用并持久化新设置。
  ///
  /// 持久化失败时（如磁盘满抛出 [FormatException]）不重新抛出，保留内存中的
  /// 乐观更新并发出 [SettingsLoaded]，避免调用方崩溃。真实环境应通过 SnackBar
  /// 等提示用户（架构 §1.2 的 storageWriteFailed）。
  Future<void> update(AppSettings settings) async {
    try {
      await _repository.save(settings);
    } catch (_) {
      // 持久化失败：保留内存中的乐观更新，不阻断 UI。
      // 真实环境应通过 SnackBar 等提示用户（架构 §1.2 的 storageWriteFailed）。
    }
    emit(SettingsLoaded(settings));
  }
}
