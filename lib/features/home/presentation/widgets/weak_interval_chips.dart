import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';

/// 薄弱音程 chips（T18 / M-07 呼吸）。
///
/// 列出当前「薄弱」档音程，点击进入只练该音程的练习。整组带一个轻微呼吸动效
/// （M-07 2200ms），`reduced` / `off` 档下停止呼吸、直接静态展示。
class WeakIntervalChips extends StatefulWidget {
  /// 创建薄弱音程 chips。
  const WeakIntervalChips({
    required this.intervals,
    required this.onTap,
    super.key,
  });

  /// 薄弱音程列表（顺序无关，内部按半音数升序渲染）。
  final List<IntervalId> intervals;

  /// 点击某个音程。
  final ValueChanged<IntervalId> onTap;

  @override
  State<WeakIntervalChips> createState() => _WeakIntervalChipsState();
}

class _WeakIntervalChipsState extends State<WeakIntervalChips>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotionTokens.standard().home.weakChipPulse.duration,
  );

  @override
  void initState() {
    super.initState();
    if (context.allowAmbient) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.allowAmbient) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<IntervalId> sorted = IntervalCatalog.sorted(widget.intervals);
    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppStrings.home.weakSectionTitle, style: tokens.type.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: tokens.space.sm,
          runSpacing: tokens.space.xs,
          children: <Widget>[
            for (final IntervalId id in sorted)
              ActionChip(
                label: Text(
                  '${IntervalCatalog.nameOf(id)} (${IntervalCatalog.shorthandOf(id)})',
                ),
                onPressed: () => widget.onTap(id),
              ),
          ],
        ),
      ],
    );

    if (!context.allowAmbient) {
      return column;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double opacity =
            0.7 + 0.3 * (0.5 + 0.5 * math.sin(_controller.value * 2 * math.pi));
        return Opacity(opacity: opacity, child: column);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
