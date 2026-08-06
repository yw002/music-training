import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 章节推进浮层（`M-23` chapter.advance：进入 300 + 停留 1600 + 退出 240）。
///
/// 整组训练触发章节解锁时展示：居中卡片先 300ms 进入、停留 1600ms、再 240ms 退出。
/// 时长经 `context.mDur` 折算当前档位；播放完调用 [onDismissed]。卡片用 success
/// 语义色，明确传达「进步」而非「惩罚」。
class ChapterAdvanceOverlay extends StatefulWidget {
  /// 创建章节推进浮层。
  const ChapterAdvanceOverlay({
    required this.chapterName,
    this.onDismissed,
    super.key,
  });

  /// 被解锁的章节名（`null` 用兜底文案）。
  final String? chapterName;

  /// 播放完毕回调。
  final VoidCallback? onDismissed;

  @override
  State<ChapterAdvanceOverlay> createState() => _ChapterAdvanceOverlayState();
}

class _ChapterAdvanceOverlayState extends State<ChapterAdvanceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _enterEnd = 1.0;
  double _holdEnd = 1.0;
  bool _didInitDeps = false;

  @override
  void initState() {
    super.initState();
    // 用默认 duration 创建控制器（不需 context），监听用于驱动透明度重绘。
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2140),
    )..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 一次性守护：祖先 provider 此时已就绪，可安全读取 tokens/mDur；
    // forward().whenComplete 保证恰好触发一次，onDismissed 仅调用一次。
    if (_didInitDeps) {
      return;
    }
    _didInitDeps = true;
    final tokens = context.tokens.motion.progress.chapterAdvance;
    final enter = context.mDur(tokens.enter.duration);
    final hold = context.mDur(tokens.hold);
    final exit = context.mDur(tokens.exit.duration);
    final totalMs = (enter + hold + exit).inMilliseconds;
    if (totalMs == 0) {
      // off 档：时长折为 0，须瞬时到达终态（架构 §8.4）。避免 0/0 产生 NaN 导致
      // build 中 withValues(alpha: NaN) 抛错。动画 duration 仍为 0，forward 会
      // 在下一帧立刻完成并触发 onDismissed。
      _enterEnd = 0.0;
      _holdEnd = 0.0;
    } else {
      _enterEnd = enter.inMilliseconds / totalMs;
      _holdEnd = (enter + hold).inMilliseconds / totalMs;
    }
    _controller.duration = Duration(milliseconds: totalMs);
    _controller.forward().whenComplete(() => widget.onDismissed?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _opacity {
    final v = _controller.value;
    if (v < _enterEnd) {
      return v / _enterEnd;
    }
    if (v < _holdEnd) {
      return 1;
    }
    final tail = (v - _holdEnd) / (1 - _holdEnd);
    return (1 - tail).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final name = widget.chapterName ?? AppStrings.training.binaryTitle;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.3 * _opacity),
          child: Center(
            child: Opacity(
              opacity: _opacity,
              child: Container(
                margin: tokens.space.pageInsets(
                  MediaQuery.of(context).size.width,
                ),
                padding: tokens.space.bigCardInsets,
                decoration: BoxDecoration(
                  color: tokens.color.success.container,
                  borderRadius: tokens.radius.card,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: tokens.scheme.shadow.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.celebration_rounded,
                      size: 48,
                      color: tokens.color.success.base,
                    ),
                    SizedBox(height: tokens.space.sm),
                    Text(
                      AppStrings.training.chapterAdvance(name),
                      style: tokens.type.titleLarge?.copyWith(
                        color: tokens.color.success.onContainer,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
