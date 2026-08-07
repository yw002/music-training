import 'package:equatable/equatable.dart';

import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 报告页状态（架构 §3.2 / T21）。
///
/// 加载 [StatsSnapshot] 供各图表消费；即便快照为空也会进入 [ReportReady]，
/// 由 UI 展示友好空态，不抛不崩。
sealed class ReportState extends Equatable {
  /// 创建报告状态。
  const ReportState();

  @override
  List<Object?> get props => <Object?>[];
}

/// 初始（尚未触发加载）。
final class ReportInitial extends ReportState {
  /// 创建初始态。
  const ReportInitial();
}

/// 加载中。
final class ReportLoading extends ReportState {
  /// 创建加载态。
  const ReportLoading();
}

/// 已加载（[snapshot] 可能为空，UI 自行判空）。
final class ReportReady extends ReportState {
  /// 创建已加载态。
  const ReportReady({required this.snapshot});

  /// 统计快照（可为空）。
  final StatsSnapshot snapshot;

  @override
  List<Object?> get props => <Object?>[snapshot];
}

/// 加载失败（仓库异常时进入，不阻塞其余 UI）。
final class ReportError extends ReportState {
  /// 创建错误态。
  const ReportError({required this.message});

  /// 错误文案。
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
