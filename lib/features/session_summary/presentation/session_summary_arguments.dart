import 'package:equatable/equatable.dart';

import 'package:interval_ear/features/training/domain/models/training_session.dart';

/// 本组小结页的路由参数（架构 §3.3）。
///
/// [TrainingPage] 在 finished 态经 `pushNamed(RouteNames.sessionSummary,
/// arguments:)` 传入；路由处理器用 `arguments as SessionSummaryArguments` 取
/// [session]。使用包装类是为了和「裸 TrainingSession」区分，消除路由参数契约在
/// 两端不一致的风险（T20 接口对齐项）。
class SessionSummaryArguments extends Equatable {
  /// 创建路由参数。
  const SessionSummaryArguments({required this.session});

  /// 本组已结算的会话记录。
  final TrainingSession session;

  @override
  List<Object?> get props => <Object?>[session];
}
