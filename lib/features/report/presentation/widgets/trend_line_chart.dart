import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/report/presentation/painters/line_chart_painter.dart';
import 'package:interval_ear/features/training/domain/stats/daily_summary.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 正确率趋势折线图（M-26 描边 800ms）。
///
/// 支持近 7 天 / 近 30 天 / 全部三档范围；线条从最旧点向最新点描出（[grow]）。
/// 时间窗锚点 [now] 注入，避免 `DateTime.now()`。
class TrendLineChart extends StatefulWidget {
  /// 创建趋势折线图。
  const TrendLineChart({required this.snapshot, required this.now, super.key});

  /// 统计快照。
  final StatsSnapshot snapshot;

  /// 时间窗锚点（当前时刻）。
  final DateTime now;

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _days = 7;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // 时长依赖 context.tokens（Theme.of），须在 didChangeDependencies 取。
    _controller = AnimationController(vsync: this, duration: Duration.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // M-26 折线：800ms standard 描边。
    _controller.duration =
        context.mDur(context.tokens.motion.report.lineGrow.duration);
    if (_started) {
      return;
    }
    _started = true;
    if (context.motionLevel == MotionLevel.full) {
      _controller.forward();
    } else {
      _controller.value = _controller.upperBound;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<DailySummary> _series() {
    if (_days == 0) {
      final List<DailySummary> all =
          widget.snapshot.daily.values.toList()
            ..sort(DailySummary.compareByDate);
      return all;
    }
    return widget.snapshot.recentDays(_days, widget.now);
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<DailySummary> series = _series();
    final List<double> values = <double>[
      for (final DailySummary d in series) d.accuracy,
    ];
    final List<String> labels = <String>[
      for (final DailySummary d in series)
        '${d.anchor?.month ?? 0}/${d.anchor?.day ?? 0}',
    ];

    return Card(
      child: Padding(
        padding: tokens.space.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _RangeToggle(days: _days, onChanged: (int d) => setState(() => _days = d)),
            SizedBox(height: tokens.space.sm),
            SizedBox(
              height: 200,
              child: CustomPaint(
                painter: LineChartPainter(
                  values: values,
                  labels: labels,
                  grow: _controller.value,
                  lineColor: tokens.color.success.base,
                  areaColor: tokens.color.success.base.withValues(alpha: 0.15),
                  gridColor: tokens.scheme.outlineVariant,
                  axisColor: tokens.scheme.outline,
                  labelColor: tokens.scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 范围切换（近 7 天 / 近 30 天 / 全部）。
class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Map<int, String> options = <int, String>{
      7: AppStrings.report.range7Days,
      30: AppStrings.report.range30Days,
      0: AppStrings.report.rangeAll,
    };
    return Wrap(
      spacing: tokens.space.xs,
      children: options.entries
          .map(
            (MapEntry<int, String> e) => ChoiceChip(
              label: Text(e.value),
              selected: days == e.key,
              onSelected: (_) => onChanged(e.key),
            ),
          )
          .toList(),
    );
  }
}
