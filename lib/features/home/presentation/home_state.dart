import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 首页状态（架构 §3.5 / T18）。
///
/// 加载完成后产出 [HomeLoaded]，携带：统计快照、弱项音程列表、今日推荐配置、
/// 连续练习天数，以及一次性的「记录已修复」提示条计数。
@immutable
sealed class HomeState extends Equatable {
  /// 创建状态。
  const HomeState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// 尚未开始加载（Cubit 构造瞬间）。
final class HomeInitial extends HomeState {
  /// 创建初始状态。
  const HomeInitial();
}

/// 正在加载统计。
final class HomeLoading extends HomeState {
  /// 创建加载中状态。
  const HomeLoading();
}

/// 已加载（可渲染首页全部内容）。
final class HomeLoaded extends HomeState {
  /// 创建已加载状态。
  const HomeLoaded({
    required this.snapshot,
    required this.weakIntervals,
    required this.todayConfig,
    required this.streakDays,
    this.recoveryDroppedLines = 0,
  });

  /// 全量统计快照。
  final StatsSnapshot snapshot;

  /// 当前处于「薄弱」档的音程（按半音数升序由 UI 渲染）。
  final List<IntervalId> weakIntervals;

  /// 今日推荐的练习配置。
  final TrainingConfig todayConfig;

  /// 连续练习天数（今天没练则从昨天起算）。
  final int streakDays;

  /// 本次加载时恢复的记录行数（>0 时显示一次性修复提示）。
  final int recoveryDroppedLines;

  @override
  List<Object?> get props => <Object?>[
        snapshot,
        weakIntervals,
        todayConfig,
        streakDays,
        recoveryDroppedLines,
      ];
}
