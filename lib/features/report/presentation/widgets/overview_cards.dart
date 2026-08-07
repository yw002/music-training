import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/curves.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/utils/math_utils.dart';
import 'package:interval_ear/features/report/presentation/painters/ring_painter.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/services/mastery_calculator.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 报告总览卡片（架构 §2.6 / T21）。
///
/// 顶部正确率环（[RingPainter]，M-26 生长）+ 累计题数 / 练习天数 / 已掌握数等统计。
/// 数据来自 [StatsSnapshot]。
class OverviewCards extends StatelessWidget {
  /// 创建总览卡片。
  const OverviewCards({required this.snapshot, super.key});

  /// 统计快照。
  final StatsSnapshot snapshot;

  int _masteredCount() {
    int count = 0;
    for (final IntervalId id in IntervalCatalog.trainableIds) {
      final MasteryBucket bucket =
          MasteryCalculator.bucketOfStats(snapshot.intervalOf(id));
      if (bucket == MasteryBucket.strong || bucket == MasteryBucket.mastered) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final double accuracy = snapshot.overallAccuracy();
    final int practicedDays =
        snapshot.daily.values.where((d) => d.isActive).length;
    final int questions = snapshot.totalQuestions;
    final int mastered = _masteredCount();

    return Card(
      child: Padding(
        padding: tokens.space.cardInsets,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _AccuracyRing(accuracy: accuracy),
            SizedBox(width: tokens.space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _StatTile(
                    label: AppStrings.report.totalQuestions,
                    value: questions.toString(),
                  ),
                  _StatTile(
                    label: AppStrings.report.practiceDays,
                    value: practicedDays.toString(),
                  ),
                  _StatTile(
                    label: AppStrings.report.masteredCount,
                    value: mastered.toString(),
                  ),
                  _StatTile(
                    label: AppStrings.report.overallAccuracy,
                    value: '${MathUtils.toPercent(accuracy)}%',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条统计（标签 + 数值）。
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.space.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              style: tokens.type.bodyMedium
                  ?.copyWith(color: tokens.scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: tokens.space.sm),
          Text(
            value,
            style: tokens.type.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// 正确率环（动画驱动 [RingPainter]，M-26 生长）。
class _AccuracyRing extends StatefulWidget {
  const _AccuracyRing({required this.accuracy});

  final double accuracy;

  @override
  State<_AccuracyRing> createState() => _AccuracyRingState();
}

class _AccuracyRingState extends State<_AccuracyRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _grow;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // 时长依赖 context.tokens（Theme.of），必须放到 didChangeDependencies 取，
    // 不能在 initState 读 inherited widget（架构 §8.4）。
    _controller = AnimationController(vsync: this, duration: Duration.zero);
    _grow = CurvedAnimation(
      parent: _controller,
      curve: AppCurve.emphasizedDecelerate,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // M-26 生长：520ms emphasizedDecelerate，时长经 context.mDur 折算当前档位。
    _controller.duration =
        context.mDur(context.tokens.motion.report.barGrow.item.duration);
    if (_started) {
      return;
    }
    _started = true;
    if (context.motionLevel == MotionLevel.full) {
      _controller.forward();
    } else {
      // 降级档：跳过生长过程，直接展示终态（架构 §8.4）。
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
    final Color arcColor = widget.accuracy >= 0.6
        ? tokens.color.success.base
        : tokens.color.warning.base;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            painter: RingPainter(
              progress: widget.accuracy,
              grow: _grow.value,
              trackColor: tokens.scheme.surfaceContainerHighest,
              arcColor: arcColor,
              stroke: tokens.space.md,
            ),
          ),
          Text(
            '${MathUtils.toPercent(widget.accuracy)}%',
            style: tokens.type.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
