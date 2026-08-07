import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';
import 'package:interval_ear/features/report/presentation/painters/matrix_painter.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/stats/confusion_entry.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 混淆矩阵视图（13×13，M-27 波次揭示 260/22/900）。
///
/// 行=实际音程，列=所选音程（[buildCounts] 保证此映射）；对角线=答对（success 色），
/// 非对角=混淆（warning 色）。下方列出最易混淆的若干对。纯展示，不泄露音高。
class ConfusionMatrixView extends StatefulWidget {
  /// 创建混淆矩阵视图。
  const ConfusionMatrixView({required this.snapshot, super.key});

  /// 统计快照。
  final StatsSnapshot snapshot;

  /// 纯函数：把混淆矩阵转成 13×13 counts，行=实际列=所选（供测试断言）。
  static List<List<int>> buildCounts(StatsSnapshot snapshot) {
    final List<IntervalId> ids = IntervalCatalog.trainableIds.toList();
    return <List<int>>[
      for (final IntervalId actual in ids)
        <int>[
          for (final IntervalId selected in ids)
            snapshot.confusionMatrix.countOf(actual, selected),
        ],
    ];
  }

  @override
  State<ConfusionMatrixView> createState() => _ConfusionMatrixViewState();
}

class _ConfusionMatrixViewState extends State<ConfusionMatrixView>
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
    // M-27 波次揭示：单项 260ms，步进 22ms，封顶 900ms。
    final MotionStaggerSpec spec = context.tokens.motion.report.matrixReveal;
    final int totalMs =
        spec.delayFor(2 * (IntervalCatalog.trainableIds.length - 1))
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
    final List<List<int>> counts = ConfusionMatrixView.buildCounts(widget.snapshot);
    final int maxCount = math.max(widget.snapshot.confusionMatrix.maxCount(), 1);
    final bool hasData = widget.snapshot.confusionMatrix.totalCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 320,
          child: CustomPaint(
            painter: MatrixPainter(
              counts: counts,
              reveal: _controller.value,
              maxCount: maxCount,
              diagonalColor: tokens.color.success.base,
              offColor: tokens.color.warning.base,
              textColor: tokens.scheme.onSurface,
              gridColor: tokens.scheme.outlineVariant,
              emptyColor:
                  tokens.scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              rowLabels: <String>[
                for (final IntervalId id in ids) IntervalCatalog.shorthandOf(id),
              ],
              columnLabels: <String>[
                for (final IntervalId id in ids) IntervalCatalog.shorthandOf(id),
              ],
            ),
          ),
        ),
        if (hasData) ..._topPairs(context),
      ],
    );
  }

  List<Widget> _topPairs(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<ConfusionEntry> top =
        widget.snapshot.confusionMatrix.topEntries(3, includeDiagonal: false);
    if (top.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      SizedBox(height: tokens.space.sm),
      for (final ConfusionEntry e in top)
        Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.space.xxs),
          child: Text(
            '${AppStrings.report.confusionPair(IntervalCatalog.nameOf(e.actual), IntervalCatalog.nameOf(e.selected))}'
            ' · ${AppStrings.report.confusionTimes(e.count)}',
            style: tokens.type.bodySmall
                ?.copyWith(color: tokens.scheme.onSurfaceVariant),
          ),
        ),
    ];
  }
}
