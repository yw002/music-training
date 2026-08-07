import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/report/presentation/painters/heatmap_painter.dart';
import 'package:interval_ear/features/training/domain/stats/daily_summary.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 每日练习热力图（近 5 周，架构 §2.6 / T21 验收 ⑤）。
///
/// 每 7 天为一列（周），列=时间推进（最旧在左）。颜色强度按当日题数归一化。
/// 静态度量概览，不做生长动画。
class DailyHeatmap extends StatelessWidget {
  /// 创建每日热力图。
  const DailyHeatmap({required this.snapshot, required this.now, super.key});

  /// 统计快照。
  final StatsSnapshot snapshot;

  /// 时间窗锚点（当前时刻）。
  final DateTime now;

  static const int _rows = 7;
  static const int _days = 35;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<DailySummary> series = snapshot.recentDays(_days, now);
    final int maxQ = series.fold(
      0,
      (int a, DailySummary d) => math.max(a, d.questionCount),
    );
    final List<double> values = <double>[
      for (final DailySummary d in series)
        maxQ <= 0 ? 0 : d.questionCount / maxQ,
    ];

    return Card(
      child: Padding(
        padding: tokens.space.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(AppStrings.report.heatmapSection, style: tokens.type.labelLarge),
            SizedBox(height: tokens.space.sm),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: HeatmapPainter(
                  values: values,
                  rows: _rows,
                  grow: 1,
                  baseColor: tokens.color.success.base,
                  emptyColor: tokens.scheme.surfaceContainerHighest,
                  gap: tokens.space.xxs,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
