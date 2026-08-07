import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';
import 'package:interval_ear/core/utils/math_utils.dart';
import 'package:interval_ear/features/report/presentation/painters/bar_chart_painter.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 各音程正确率柱状图（13 音程，M-26 交错生长 520/40）。
///
/// 每根柱子独立生长（按 [IntervalCatalog] 半音序），颜色取音程标识色；未练习的
/// 音程正确率为 0，仍占位显示，保持 13 根一致可比。
class IntervalAccuracyChart extends StatefulWidget {
  /// 创建柱状图。
  const IntervalAccuracyChart({required this.snapshot, super.key});

  /// 统计快照。
  final StatsSnapshot snapshot;

  @override
  State<IntervalAccuracyChart> createState() => _IntervalAccuracyChartState();
}

class _IntervalAccuracyChartState extends State<IntervalAccuracyChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
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
    // M-26 交错：单项 520ms，步进 40ms，封顶 480ms。
    final MotionStaggerSpec spec = context.tokens.motion.report.barGrow;
    final int totalMs = spec.delayFor(IntervalCatalog.trainableIds.length - 1)
            .inMilliseconds +
        spec.item.duration.inMilliseconds;
    _controller.duration = context.mDur(Duration(milliseconds: totalMs));
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

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<IntervalId> ids = IntervalCatalog.trainableIds.toList();
    final List<double> values = <double>[
      for (final IntervalId id in ids) widget.snapshot.intervalOf(id).rawAccuracy,
    ];
    final List<String> labels = <String>[
      for (final IntervalId id in ids) IntervalCatalog.shorthandOf(id),
    ];
    final List<Color> colors = <Color>[
      for (final IntervalId id in ids) tokens.interval.colorOf(id.semitones),
    ];

    // 每根柱子的交错生长进度（沿 r+c 对角之外的列向波次）。
    final MotionStaggerSpec spec = tokens.motion.report.barGrow;
    final int itemMs = spec.item.duration.inMilliseconds;
    final int maxDelay = spec.delayFor(ids.length - 1).inMilliseconds;
    final double t = _controller.value;
    final List<double> progress = <double>[
      for (int i = 0; i < ids.length; i++)
        MathUtils.inverseLerp(
          0,
          1,
          (t * (maxDelay + itemMs) - spec.delayFor(i).inMilliseconds) / itemMs,
        ),
    ];

    return SizedBox(
      height: 260,
      child: CustomPaint(
        painter: BarChartPainter(
          values: values,
          labels: labels,
          barColors: colors,
          barProgress: progress,
          trackColor: tokens.scheme.surfaceContainerHighest,
          axisColor: tokens.scheme.outlineVariant,
          labelColor: tokens.scheme.onSurfaceVariant,
          gridColor: tokens.scheme.outlineVariant,
        ),
      ),
    );
  }
}
