import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/curves.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_state.dart';
import 'package:interval_ear/features/session_summary/presentation/widgets/accuracy_ring.dart';

/// 本组小结头部：正确率环 + 用时 + 最长连击（架构 §2.5 / T20 验收 ①）。
///
/// 正确率数字采用 M-25 数字滚动（900ms decelerate）；`reduced/off` 档跳过过程直达
/// 终态（架构 §8.4）。正确率弧走 [AccuracyRing]（CustomPainter，M-26 生长）。
class SummaryHeader extends StatelessWidget {
  /// 创建头部。
  const SummaryHeader({required this.summary, super.key});

  /// 派生统计。
  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Card(
      child: Padding(
        padding: tokens.space.cardInsets,
        child: Column(
          children: <Widget>[
            AccuracyRing(accuracy: summary.accuracy),
            SizedBox(height: tokens.space.md),
            _RollingPercent(accuracy: summary.accuracy),
            SizedBox(height: tokens.space.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatTile(
                    label: AppStrings.summary.duration,
                    value: _formatDuration(summary.duration),
                  ),
                ),
                SizedBox(width: tokens.space.md),
                Expanded(
                  child: _StatTile(
                    label: AppStrings.summary.bestCombo,
                    value: AppStrings.unit.times('${summary.maxCombo}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 把时长格式化为「X 秒 / X 分钟 / X 分钟 Y 秒」。
  static String _formatDuration(Duration? duration) {
    if (duration == null) {
      return AppStrings.common.empty;
    }
    final int totalSeconds = duration.inSeconds;
    if (totalSeconds < 60) {
      return AppStrings.unit.seconds('$totalSeconds');
    }
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String head = AppStrings.unit.minutes('$minutes');
    if (seconds == 0) {
      return head;
    }
    return '$head ${AppStrings.unit.seconds('$seconds')}';
  }
}

/// 正确率数字滚动（M-25 900ms decelerate）。
class _RollingPercent extends StatefulWidget {
  const _RollingPercent({required this.accuracy});

  final double accuracy;

  @override
  State<_RollingPercent> createState() => _RollingPercentState();
}

class _RollingPercentState extends State<_RollingPercent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  double _from = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // duration 依赖 context.tokens（Theme.of），不能在 initState 读 inherited
    // widget，必须放到 didChangeDependencies 取（Flutter 框架约束 + 架构 §8.4）。
    _controller = AnimationController(vsync: this, duration: Duration.zero);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppCurve.decelerate,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // M-25 数字滚动：900ms decelerate，时长经 context.mDur 折算当前档位。
    _controller.duration =
        context.mDur(context.tokens.motion.report.numberRoll.duration);
    if (_started) {
      return;
    }
    _started = true;
    if (context.motionLevel == MotionLevel.full) {
      _controller.forward();
    } else {
      // 降级档：跳过滚动直达终态（架构 §8.4）。
      _controller.value = _controller.upperBound;
    }
  }

  @override
  void didUpdateWidget(covariant _RollingPercent old) {
    super.didUpdateWidget(old);
    if (old.accuracy != widget.accuracy) {
      _from = _current();
      if (context.motionLevel == MotionLevel.full) {
        _controller
          ..reset()
          ..forward();
      } else {
        _controller.value = _controller.upperBound;
      }
    }
  }

  double _current() => _from + _animation.value * (widget.accuracy - _from);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) => Text(
        AppStrings.unit.percent((_current() * 100).round()),
        style: tokens.type.headlineSmall?.copyWith(
          color: tokens.scheme.onSurface,
        ),
      ),
    );
  }
}

/// 单个统计方块（用时 / 最长连击）。
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(tokens.space.md),
      decoration: BoxDecoration(
        color: tokens.scheme.surfaceContainerHighest,
        borderRadius: tokens.radius.card,
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: tokens.type.titleLarge?.copyWith(
              color: tokens.scheme.onSurface,
            ),
          ),
          SizedBox(height: tokens.space.xs),
          Text(
            label,
            style: tokens.type.bodySmall?.copyWith(
              color: tokens.scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
