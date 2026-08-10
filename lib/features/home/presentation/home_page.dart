import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/platform/keyboard_shortcuts.dart';
import 'package:interval_ear/core/widgets/responsive/adaptive_layout.dart';
import 'package:interval_ear/core/widgets/responsive/breakpoint_scope.dart';
import 'package:interval_ear/core/widgets/responsive/responsive_builder.dart';
import 'package:interval_ear/features/home/presentation/home_cubit.dart';
import 'package:interval_ear/features/home/presentation/home_state.dart';
import 'package:interval_ear/features/home/presentation/widgets/ambient_background.dart';
import 'package:interval_ear/features/home/presentation/widgets/quick_entry_grid.dart';
import 'package:interval_ear/features/home/presentation/widgets/streak_banner.dart';
import 'package:interval_ear/features/home/presentation/widgets/today_card.dart';
import 'package:interval_ear/features/home/presentation/widgets/weak_interval_chips.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';

/// 首页（架构 §3.5 / T18 + T22 响应式与快捷键）。
///
/// 进入即 [HomeCubit.load]（读统计 → 算弱项 → 今日推荐）。零历史时弱项区不显示、
/// 今日推荐退化为第一章；统计曾损坏恢复时显示一次性提示条。
///
/// **T22 补强**：
/// - 外层包 [AppShortcuts]：`Ctrl/⌘ + R` 开始今日练习、`Ctrl/⌘ + ,` 打开设置，
///   与点击卡片走同一条导航路径；
/// - 内容区包 [ResponsiveBuilder]：expanded 断点切成「主内容 + 快捷入口侧栏」
///   双栏，compact/medium 保持既有单列。
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

  /// 键盘「开始今日练习」：与点击今日卡片走同一条导航。
  void _startToday() {
    final HomeState state = context.read<HomeCubit>().state;
    if (state is! HomeLoaded) {
      return;
    }
    Navigator.of(context).pushNamed(
      RouteNames.training,
      arguments: state.todayConfig,
    );
  }

  void _openSettings() {
    Navigator.of(context).pushNamed(RouteNames.settings);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppShortcuts(
          onStartTraining: _startToday,
          onOpenSettings: _openSettings,
          child: BlocBuilder<HomeCubit, HomeState>(
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
        ),
      );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.state});
  final HomeLoaded state;

  /// 主内容块（连胜 / 今日推荐 / 弱项 / 恢复提示），三档共用，不重复实现。
  List<Widget> _primaryBlocks(BuildContext context, AppTokens tokens) =>
      <Widget>[
        if (state.streakDays > 0) ...<Widget>[
          StreakBanner(days: state.streakDays),
          SizedBox(height: tokens.space.sm),
        ],
        TodayCard(
          config: state.todayConfig,
          onStart: () => Navigator.of(context).pushNamed(
            RouteNames.training,
            arguments: state.todayConfig,
          ),
        ),
        SizedBox(height: tokens.space.md),
        if (!state.snapshot.isEmpty && state.weakIntervals.isNotEmpty) ...<Widget>[
          WeakIntervalChips(
            intervals: state.weakIntervals,
            onTap: (IntervalId id) {
              final TrainingConfig cfg = TrainingConfig.defaults.copyWith(
                enabledIntervals: <IntervalId>{id},
              );
              Navigator.of(context)
                  .pushNamed(RouteNames.training, arguments: cfg);
            },
          ),
          SizedBox(height: tokens.space.md),
        ],
        if (state.recoveryDroppedLines > 0)
          _RecoveryBanner(dropped: state.recoveryDroppedLines),
      ];

  Widget _quickEntry(BuildContext context) => QuickEntryGrid(
        onFree: () => Navigator.of(context).pushNamed(RouteNames.freeTraining),
        onBinary: () =>
            Navigator.of(context).pushNamed(RouteNames.binaryTraining),
        onReport: () => Navigator.of(context).pushNamed(RouteNames.report),
        onSettings: () => Navigator.of(context).pushNamed(RouteNames.settings),
        onAbout: () => Navigator.of(context).pushNamed(RouteNames.about),
      );

  @override
  Widget build(BuildContext context) => ResponsiveBuilder(
        builder: (BuildContext context, Breakpoint breakpoint) {
          final AppTokens tokens = context.tokens;
          final List<Widget> primary = _primaryBlocks(context, tokens);
          final Widget quickEntry = _quickEntry(context);
          return AdaptiveLayout(
            child: ListView(
              padding: breakpoint.pageInsets.copyWith(
                top: tokens.space.lg,
                bottom: tokens.space.xl,
              ),
              children: breakpoint.isExpanded
                  ? <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: primary,
                            ),
                          ),
                          SizedBox(width: tokens.space.lg),
                          SizedBox(
                            width: breakpoint.sidePanelWidth,
                            child: quickEntry,
                          ),
                        ],
                      ),
                    ]
                  : <Widget>[...primary, quickEntry],
            ),
          );
        },
      );
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
