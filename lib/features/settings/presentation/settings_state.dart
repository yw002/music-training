import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:interval_ear/features/training/domain/models/app_settings.dart';

/// 设置页状态机（T17，架构 §1.2）。
///
/// [SettingsLoaded] 是设置页渲染与全局主题/动效映射的数据源；未加载完成前
/// 退化为 [SettingsInitial]，UI 使用 [AppSettings.defaults]。
@immutable
sealed class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => <Object?>[];
}

/// 初始态：尚未加载设置（[SettingsCubit.load] 之前）。
final class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

/// 已加载态：持有当前 [AppSettings]。
final class SettingsLoaded extends SettingsState {
  const SettingsLoaded(this.settings);

  /// 当前生效的设置。
  final AppSettings settings;

  @override
  List<Object?> get props => <Object?>[settings];
}
