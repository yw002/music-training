import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/curves.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';
import 'package:interval_ear/core/platform/keyboard_shortcuts.dart';
import 'package:interval_ear/core/widgets/responsive/breakpoint_scope.dart';
import 'package:interval_ear/core/widgets/responsive/responsive_builder.dart';
import 'package:interval_ear/features/report/presentation/report_cubit.dart';
import 'package:interval_ear/features/report/presentation/report_state.dart';
import 'package:interval_ear/features/report/presentation/widgets/confusion_matrix_view.dart';
import 'package:interval_ear/features/report/presentation/widgets/daily_heatmap.dart';
import 'package:interval_ear/features/report/presentation/widgets/dimension_breakdown.dart';
import 'package:interval_ear/features/report/presentation/widgets/empty_report_state.dart';
import 'package:interval_ear/features/report/presentation/widgets/interval_accuracy_chart.dart';
import 'package:interval_ear/features/report/presentation/widgets/overview_cards.dart';
import 'package:interval_ear/features/report/presentation/widgets/trend_line_chart.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 训练报告页（架构 §2.6 / T21）。
///
/// 经路由工厂 `const ReportPage()` 创建；本页用 [BlocProvider] 创建
/// [ReportCubit]（从仓储读取统计），进入即 [ReportCubit.load]。各图表均为
/// CustomPainter（架构 §7.3 禁止 fl_chart）。分区按 M-24 交错入场（360/120）。
class ReportPage extends StatelessWidget {
  /// 创建报告页。
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<ReportCubit>(
        create: (_) => ReportCubit(
          trainingRepo: context.read<TrainingRepository>(),
        ),
        child: const _ReportView(),
      );
}

class _ReportView extends StatefulWidget {
  const _ReportView();

  @override
  State<_ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<_ReportView> {
  @override
  void initState() {
    super.initState();
    // 进入即加载（HomePage 同款模式；context.read 在 initState 读 Cubit 是允许的，
    // 不读 tokens/Theme/MotionScope）。
    context.read<ReportCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Scaffold(
      backgroundColor: tokens.scheme.surface,
      appBar: AppBar(
        title: Text(AppStrings.report.title),
        centerTitle: false,
        automaticallyImplyLeading: true,
      ),
      // T22：报告页也接入统一快捷键（Esc 返回、Ctrl/⌘+, 打开设置），
      // 与点击返回箭头 / 设置入口走同一条导航路径。
      body: AppShortcuts(
        onDismiss: () => Navigator.of(context).maybePop(),
        onOpenSettings: () =>
            Navigator.of(context).pushNamed(RouteNames.settings),
        child: BlocBuilder<ReportCubit, ReportState>(
          builder: (BuildContext context, ReportState state) {
            if (state is ReportLoading || state is ReportInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ReportError) {
              return Center(
                child: Text(
                  state.message,
                  style: tokens.type.bodyMedium
                      ?.copyWith(color: tokens.scheme.onSurfaceVariant),
                ),
              );
            }
            final StatsSnapshot snapshot = (state as ReportReady).snapshot;
            if (snapshot.isEmpty) {
              return const EmptyReportState();
            }
            return _ReportContent(snapshot: snapshot);
          },
        ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.snapshot});

  final StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) => ResponsiveBuilder(
        builder: (BuildContext context, Breakpoint breakpoint) =>
            _content(context, breakpoint),
      );

  /// 三档共用的分区列表；只有「单列 / 双列」这一处按断点分流（§8.3 最小变更）。
  Widget _content(BuildContext context, Breakpoint breakpoint) {
    final AppTokens tokens = context.tokens;
    final DateTime now = context.read<ReportCubit>().now;
    final List<(String, Widget)> blocks = <(String, Widget)>[
      (AppStrings.report.overviewSection, OverviewCards(snapshot: snapshot)),
      (AppStrings.report.trendSection,
          TrendLineChart(snapshot: snapshot, now: now)),
      (AppStrings.report.perIntervalSection,
          IntervalAccuracyChart(snapshot: snapshot)),
      (AppStrings.report.confusionSection,
          ConfusionMatrixView(snapshot: snapshot)),
      (AppStrings.report.dimensionSection,
          DimensionBreakdown(dimensions: snapshot.dimensions)),
      (AppStrings.report.heatmapSection,
          DailyHeatmap(snapshot: snapshot, now: now)),
    ];

    final List<Widget> children = <Widget>[];
    for (int i = 0; i < blocks.length; i++) {
      children.add(
        _Entrance(
          index: i,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SectionTitle(blocks[i].$1),
              SizedBox(height: tokens.space.sm),
              blocks[i].$2,
              SizedBox(height: tokens.space.sectionGap),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: tokens.space.pageInsets(MediaQuery.of(context).size.width).copyWith(
        top: tokens.space.lg,
        bottom: tokens.space.xl,
      ),
      children: children,
    );
  }
}

/// 分区标题。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Text(
      title,
      style: tokens.type.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// 分区交错入场（M-24：单项 360ms，步进 120ms）。
class _Entrance extends StatefulWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // 时长依赖 context.tokens（Theme.of），须在 didChangeDependencies 取。
    _controller = AnimationController(vsync: this, duration: Duration.zero);
    _anim = CurvedAnimation(
      parent: _controller,
      curve: AppCurve.emphasizedDecelerate,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // M-24 入场：360ms emphasizedDecelerate，步进 120ms。
    final MotionStaggerSpec spec = context.tokens.motion.report.entrance;
    _controller.duration = context.mDur(spec.item.duration);
    if (_started) {
      return;
    }
    _started = true;
    if (context.motionLevel == MotionLevel.full) {
      final Duration delay = spec.delayFor(widget.index);
      Future<void>.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.value = _controller.upperBound;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _anim.value) * 16),
            child: widget.child,
          ),
        ),
      );
}
