import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/training/presentation/feedback/feedback_tokens.dart';

/// 答对闪光（架构 §3.5 / T13，`M-15` feedback.correct）。
///
/// 答对瞬间的一记成功闪光：620ms 内先亮后淡，`reduced`/`off` 档下时长经
/// `context.mDur` 折算（off 归零直达终态）。前 180ms（`M-15` 的阻塞段）用
/// [AbsorbPointer] 拦截输入，防止用户抢在反馈未呈现完就点「下一题」——但 180ms
/// 之后必须允许打断（PRD B-1）。
class CorrectFlash extends StatefulWidget {
  /// 创建答对闪光。
  const CorrectFlash({super.key});

  @override
  State<CorrectFlash> createState() => _CorrectFlashState();
}

class _CorrectFlashState extends State<CorrectFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _blocking = true;

  @override
  void initState() {
    super.initState();
    final duration = context.mDur(FeedbackTokens.correct);
    _controller = AnimationController(vsync: this, duration: duration)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    final blockMs = context.mDur(FeedbackTokens.correctBlocking).inMilliseconds;
    if (blockMs <= 0 || duration.inMilliseconds <= 0) {
      _blocking = false;
    } else {
      Future<void>.delayed(Duration(milliseconds: blockMs), () {
        if (mounted) {
          setState(() => _blocking = false);
        }
      });
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // 先亮后淡：value 0→1 时 opacity 呈半个正弦。
    final opacity = math.sin(math.pi * _controller.value).clamp(0.0, 1.0);
    return IgnorePointer(
      ignoring: !_blocking,
      child: AbsorbPointer(
        absorbing: _blocking,
        child: Opacity(
          opacity: opacity,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: <Color>[
                  tokens.color.success.base.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
                radius: 0.7,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.check_circle_rounded,
                color: tokens.color.success.base,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
