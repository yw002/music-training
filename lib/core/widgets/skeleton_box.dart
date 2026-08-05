import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// 骨架屏色块（`M-32 skeleton`）。
///
/// 1200ms linear 循环 shimmer；`MotionLevel.reduced / off` 时停止流光，
/// 保留静态灰块（PRD §3.10：装饰性动画可以停，信息不能丢）。
class SkeletonBox extends StatefulWidget {
  /// 创建骨架块。
  const SkeletonBox({
    this.width,
    this.height = 16,
    this.borderRadius,
    this.margin,
    super.key,
  });

  /// 宽度；为空时撑满父容器。
  final double? width;

  /// 高度。
  final double height;

  /// 圆角；默认走 `radius.sm`。
  final BorderRadius? borderRadius;

  /// 外边距。
  final EdgeInsetsGeometry? margin;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const AppMotionTokens.standard().common.skeletonShimmer.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayState();
  }

  void _syncPlayState() {
    final bool shouldRun = context.motionLevel == MotionLevel.full;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
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
    final BorderRadius radius =
        widget.borderRadius ?? BorderRadius.circular(tokens.radius.sm);
    final Color base = tokens.elevation.e1.surface;
    final Color highlight = tokens.scheme.surfaceContainerHighest;

    final Widget box = SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          if (!_controller.isAnimating) {
            return DecoratedBox(
              decoration: BoxDecoration(color: base, borderRadius: radius),
            );
          }
          final double t = _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment(-1 - 2 * (1 - t), 0),
                end: Alignment(1 - 2 * (1 - t), 0),
                colors: <Color>[base, highlight, base],
                stops: const <double>[0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );

    return widget.margin == null
        ? box
        : Padding(padding: widget.margin!, child: box);
  }
}

/// 「延迟出现」的骨架屏容器（`M-32` 的 120ms 阈值）。
///
/// [ready] 为 `false` 时并不会立刻显示骨架，而是等 `skeletonShowDelay`；
/// 若在阈值内数据就绪则完全不显示，避免闪一下造成的视觉噪音。
class DelayedSkeleton extends StatefulWidget {
  /// 创建延迟骨架容器。
  const DelayedSkeleton({
    required this.ready,
    required this.skeleton,
    required this.child,
    this.delay,
    super.key,
  });

  /// 数据是否已就绪。
  final bool ready;

  /// 未就绪时展示的骨架。
  final Widget skeleton;

  /// 就绪后展示的内容。
  final Widget child;

  /// 覆盖延迟阈值。
  final Duration? delay;

  @override
  State<DelayedSkeleton> createState() => _DelayedSkeletonState();
}

class _DelayedSkeletonState extends State<DelayedSkeleton> {
  bool _showSkeleton = false;
  int _scheduleToken = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(DelayedSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready) {
      _schedule();
    }
  }

  void _schedule() {
    _scheduleToken++;
    if (widget.ready) {
      if (_showSkeleton) {
        setState(() => _showSkeleton = false);
      }
      return;
    }
    final int token = _scheduleToken;
    final Duration delay = widget.delay ??
        const AppMotionTokens.standard().common.skeletonShowDelay;
    Future<void>.delayed(delay, () {
      if (!mounted || token != _scheduleToken || widget.ready) {
        return;
      }
      setState(() => _showSkeleton = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ready) {
      return widget.child;
    }
    return _showSkeleton ? widget.skeleton : const SizedBox.shrink();
  }
}
