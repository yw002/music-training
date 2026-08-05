import 'dart:async';

import 'package:flutter/material.dart';

import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// 通用交错入场（`M-05` / `M-17` / `M-24` / `M-27` / `M-28`）。
///
/// 降级行为遵循架构 §8.4 的铁律：**跳过过程，直达终态**。
/// `MotionLevel.off` 下不创建任何 `AnimationController`，直接渲染终态；
/// `reduced` 下只保留 opacity crossfade（去掉位移），时长压到 ≤150ms 且无延迟。
class StaggeredEntrance extends StatefulWidget {
  /// 创建交错入场。
  const StaggeredEntrance({
    required this.index,
    required this.spec,
    required this.child,
    this.slideOffset = const Offset(0, 16),
    super.key,
  });

  /// 本项在列表中的下标，决定入场延迟。
  final int index;

  /// 交错规格，来自 `context.tokens.motion.*`。
  final MotionStaggerSpec spec;

  /// 位移起点（逻辑像素）。`reduced` 起被忽略。
  final Offset slideOffset;

  /// 子组件。
  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.spec.item.duration,
  );
  Timer? _startTimer;
  MotionLevel? _appliedLevel;

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final level = context.motionLevel;
    if (_appliedLevel == level) {
      return;
    }
    _appliedLevel = level;
    _schedule(level);
  }

  void _schedule(MotionLevel level) {
    _startTimer?.cancel();
    if (level == MotionLevel.off) {
      // 瞬时到终态：不排定时器，也不跑控制器。
      _controller
        ..duration = Duration.zero
        ..value = 1;
      return;
    }
    _controller.duration = widget.spec.item.effectiveDurationFor(level);
    if (level == MotionLevel.reduced) {
      // 精简档取消交错延迟：交错本身就是装饰，且会拖慢感知到达时间。
      _controller.forward(from: 0);
      return;
    }
    final delay = widget.spec.delayFor(widget.index);
    if (delay == Duration.zero) {
      _controller.forward(from: 0);
      return;
    }
    _startTimer = Timer(delay, () {
      if (mounted) {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = context.motionLevel;
    if (level == MotionLevel.off) {
      return widget.child;
    }
    final curved = CurvedAnimation(
      parent: _controller,
      curve: level == MotionLevel.full
          ? widget.spec.item.curve
          : Curves.linear,
    );
    final allowTransform = level.allowsTransform;
    return AnimatedBuilder(
      animation: curved,
      builder: (BuildContext context, Widget? child) {
        final t = curved.value;
        final content = Opacity(opacity: t.clamp(0.0, 1.0), child: child);
        if (!allowTransform) {
          return content;
        }
        return Transform.translate(
          offset: Offset(
            widget.slideOffset.dx * (1 - t),
            widget.slideOffset.dy * (1 - t),
          ),
          child: content,
        );
      },
      child: widget.child,
    );
  }
}

/// 交错入场的纯函数工具，供 `CustomPainter` / 手写控制器复用。
abstract final class Stagger {
  const Stagger._();

  /// 第 [index] 项在给定档位下的入场延迟。
  ///
  /// `reduced` / `off` 一律返回 [Duration.zero]——交错是装饰，降级时优先保证
  /// 内容立刻可读。
  static Duration delayFor(
    int index,
    MotionStaggerSpec spec,
    MotionLevel level,
  ) {
    if (level != MotionLevel.full) {
      return Duration.zero;
    }
    return spec.delayFor(index);
  }

  /// 把「全局进度 [t]」换算成第 [index] 项的局部进度 `[0, 1]`。
  ///
  /// 用于单个 `AnimationController` 驱动整组交错（比每项一个 controller 省很多）。
  static double localProgress({
    required double t,
    required int index,
    required MotionStaggerSpec spec,
    required MotionLevel level,
  }) {
    if (level != MotionLevel.full) {
      return t.clamp(0.0, 1.0);
    }
    final delayMs = spec.delayFor(index).inMilliseconds;
    final itemMs = spec.item.duration.inMilliseconds;
    if (itemMs <= 0) {
      return 1;
    }
    final totalMs = delayMs + itemMs;
    final elapsedMs = t.clamp(0.0, 1.0) * totalMs;
    final local = (elapsedMs - delayMs) / itemMs;
    return local.clamp(0.0, 1.0);
  }
}
