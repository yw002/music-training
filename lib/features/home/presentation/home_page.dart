import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/home/presentation/home_cubit.dart';
import 'package:interval_ear/features/home/presentation/home_state.dart';
import 'package:interval_ear/features/home/presentation/widgets/ambient_background.dart';
import 'package:interval_ear/features/home/presentation/widgets/quick_entry_grid.dart';
import 'package:interval_ear/features/home/presentation/widgets/streak_banner.dart';
import 'package:interval_ear/features/home/presentation/widgets/today_card.dart';
import 'package:interval_ear/features/home/presentation/widgets/weak_interval_chips.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';

/// 首页（架构 §3.5 / T18）。
///
/// 进入即 [HomeCubit.load]（读统计 → 算弱项 → 今日推荐）。零历史时弱项区不显示、
/// 今日推荐退化为第一章；统计曾损坏恢复时显示一次性提示条。
class HomePage extends StatefulWidget {
  /// 创建首页。
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: BlocBuilder<HomeCubit, HomeState>(
          builder: (BuildContext context, HomeState state) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const AmbientBackground(),
              SafeArea(
                child: state is HomeLoaded
                    ? _HomeContent(state: state)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.state});
  final HomeLoaded state;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final double width = MediaQuery.of(context).size.width;
    return ListView(
      padding: tokens.space.pageInsets(width).copyWith(
            top: tokens.space.lg,
            bottom: tokens.space.xl,
          ),
      children: <Widget>[
        if (state.streakDays > 0) ...<Widget>[
          StreakBanner(days: state.streakDays),
          const SizedBox(height: 12),
        ],
        TodayCard(
          config: state.todayConfig,
          onStart: () => Navigator.of(context).pushNamed(
            RouteNames.training,
            arguments: state.todayConfig,
          ),
        ),
        const SizedBox(height: 16),
        if (!state.snapshot.isEmpty && state.weakIntervals.isNotEmpty) ...<Widget>[
          WeakIntervalChips(
            intervals: state.weakIntervals,
            onTap: (IntervalId id) {
              final TrainingConfig cfg = TrainingConfig.defaults.copyWith(
                enabledIntervals: <IntervalId>{id},
              );
              Navigator.of(context).pushNamed(RouteNames.training, arguments: cfg);
            },
          ),
          const SizedBox(height: 16),
        ],
        if (state.recoveryDroppedLines > 0)
          _RecoveryBanner(dropped: state.recoveryDroppedLines),
        QuickEntryGrid(
          onFree: () => Navigator.of(context).pushNamed(RouteNames.freeTraining),
          onBinary: () =>
              Navigator.of(context).pushNamed(RouteNames.binaryTraining),
          onReport: () => Navigator.of(context).pushNamed(RouteNames.report),
          onSettings: () => Navigator.of(context).pushNamed(RouteNames.settings),
          onAbout: () => Navigator.of(context).pushNamed(RouteNames.about),
        ),
      ],
    );
  }
}

class _RecoveryBanner extends StatelessWidget {
  const _RecoveryBanner({required this.dropped});
  final int dropped;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.md),
      child: Container(
        padding: EdgeInsets.all(tokens.space.md),
        decoration: BoxDecoration(
          color: tokens.color.warning.container,
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
        child: Text(
          AppStrings.errors.recordsRecovered(dropped),
          style: tokens.type.bodySmall?.copyWith(
            color: tokens.color.warning.onContainer,
          ),
        ),
      ),
    );
  }
}
