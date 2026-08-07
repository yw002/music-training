import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/features/report/presentation/report_state.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 报告页状态驱动器（架构 §3.2 / T21）。
///
/// 加载 [StatsSnapshot] 供各图表消费；空数据不崩（进入 [ReportReady] 空快照，
/// UI 显示友好空态）。[clock] 注入用于趋势/热力图「最近 N 天」时间窗锚点，
/// 测试可替身为固定时刻，避免 `DateTime.now()`。
class ReportCubit extends Cubit<ReportState> {
  /// 创建报告 Cubit。
  ReportCubit({
    required TrainingRepository trainingRepo,
    DateTime Function()? clock,
  })  : _trainingRepo = trainingRepo,
        _clock = clock ?? DateTime.now,
        super(const ReportInitial());

  final TrainingRepository _trainingRepo;
  final DateTime Function() _clock;

  /// 当前时刻（趋势/热力图时间窗锚点）。
  DateTime get now => _clock();

  /// 加载统计快照。
  Future<void> load() async {
    emit(const ReportLoading());
    try {
      final StatsSnapshot snapshot = await _trainingRepo.loadStats();
      emit(ReportReady(snapshot: snapshot));
    } on Object {
      // 仓库异常时进入错误态，UI 仍可正常渲染外壳，不崩溃。
      emit(const ReportError(message: '加载报告失败'));
    }
  }
}
