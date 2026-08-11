import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/features/home/presentation/home_state.dart';
import 'package:interval_ear/features/training/domain/models/course_preset.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/repositories/recovery_report.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/services/mastery_calculator.dart';
import 'package:interval_ear/features/training/domain/stats/daily_summary.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 首页状态驱动器（架构 §3.5 / T18）。
///
/// 职责：加载统计 → 计算弱项（[MasteryCalculator]）→ 生成今日推荐配置 → 计算
/// 连续打卡天数，全部打包成 [HomeLoaded]。它**只生成 config**，真正的自适应加权
/// 组卷发生在 [TrainingCubit.start] 内的 [SessionRunner]，首页不重复实现。
class HomeCubit extends Cubit<HomeState> {
  /// 创建首页 Cubit。
  HomeCubit({
    required TrainingRepository trainingRepo,
    Timbre defaultTimbre = Timbre.keyboard,
    DateTime Function()? clock,
  })  : _trainingRepo = trainingRepo,
        _defaultTimbre = defaultTimbre,
        _clock = clock ?? DateTime.now,
        super(const HomeInitial());

  final TrainingRepository _trainingRepo;
  final Timbre _defaultTimbre;
  final DateTime Function() _clock;

  /// 加载统计并计算结果。
  Future<void> load() async {
    emit(const HomeLoading());
    final StatsSnapshot snapshot = await _trainingRepo.loadStats();
    final RecoveryReport? report = await _trainingRepo.takeRecoveryReport();

    // 弱项：遍历全部可训练音程，mastery 落在 weak 桶即入选。
    final List<IntervalId> weak = <IntervalId>[
      for (final IntervalId id in IntervalCatalog.trainableIds)
        if (MasteryCalculator.bucketOfStats(snapshot.intervalOf(id)) ==
            MasteryBucket.weak)
          id,
    ];

    // 今日推荐：零历史退化到第一章（3 个完全协和音程），否则用全量默认值，
    // 自适应加权交给 TrainingCubit（架构 §4.3 边界表）。
    final TrainingConfig recommendation = snapshot.isEmpty
        ? CourseChapters.one.toConfig(TrainingConfig.defaults)
        : TrainingConfig.defaults;
    final TrainingConfig todayConfig = recommendation.copyWith(
      timbreMode: _defaultTimbre == Timbre.plucked
          ? TimbreMode.plucked
          : TimbreMode.keyboard,
    );

    final int streak = _computeStreak(snapshot);

    emit(
      HomeLoaded(
        snapshot: snapshot,
        weakIntervals: weak,
        todayConfig: todayConfig,
        streakDays: streak,
        recoveryDroppedLines: report?.skippedAttemptLines ?? 0,
      ),
    );
  }

  /// 从今天往前数连续有练习的天数（今天没练则从昨天起算，不中断连击）。
  int _computeStreak(StatsSnapshot snapshot) {
    final DateTime now = _clock();
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final DateTime day = now.subtract(Duration(days: i));
      final bool active = snapshot.dayOf(DateKeys.of(day)).isActive;
      if (active) {
        streak++;
      } else if (i == 0) {
        // 今天还没练，连击从昨天延续，不算中断。
        continue;
      } else {
        break;
      }
    }
    return streak;
  }
}
