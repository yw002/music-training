import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/presentation/feedback/ab_compare_button.dart';
import 'package:interval_ear/features/training/presentation/feedback/feedback_controller.dart';
import 'package:interval_ear/features/training/presentation/feedback/feedback_tokens.dart';
import 'package:interval_ear/features/training/presentation/feedback/interval_info_card.dart';
import 'package:interval_ear/features/training/presentation/feedback/semitone_ruler.dart';

/// 错题面板（架构 §3.5 / T13，验收「无惩罚感」）。
///
/// 答错后展开：答案信息卡 + 半音尺 + A/B 对比 + 记忆提示。整体走中性色调，不堆砌
/// 红色警示，避免用户产生「被惩罚」的挫败感（PRD §3 反馈中性化）。
///
/// 入场遵循 `M-17`：面板 420ms + 内部 80/140/200/280 非均匀交错（见
/// [FeedbackTokens.wrongPanelEnter]），时长经 `context.mDur` 折算当前档位。
class WrongAnswerPanel extends StatelessWidget {
  /// 创建错题面板。
  const WrongAnswerPanel({
    required this.audio,
    required this.question,
    required this.attempt,
    super.key,
  });

  /// 音频服务（对比播放）。
  final AudioService audio;

  /// 已答题目。
  final IntervalQuestion question;

  /// 本次作答。
  final TrainingAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enter = FeedbackTokens.wrongPanelEnter;

    return FeedbackController(
      audio: audio,
      question: question,
      attempt: attempt,
      builder: (ctx, handle) => Container(
        margin: EdgeInsets.only(top: tokens.space.md),
        padding: tokens.space.cardInsets,
        decoration: BoxDecoration(
          color: tokens.color.uncertain.container.withValues(alpha: 0.5),
          borderRadius: tokens.radius.card,
          border: Border.all(color: tokens.color.answerBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _StaggeredChild(
              delay: enter.delayFor(0),
              duration: context.mDur(enter.item.duration),
              child: IntervalInfoCard(
                correctInterval: attempt.correctInterval,
                selectedInterval: attempt.selectedInterval,
                isUncertain: attempt.isUncertain,
              ),
            ),
            SizedBox(height: tokens.space.md),
            _StaggeredChild(
              delay: enter.delayFor(1),
              duration: context.mDur(enter.item.duration),
              child: SemitoneRuler(
                correctInterval: attempt.correctInterval,
                selectedInterval: attempt.selectedInterval,
              ),
            ),
            SizedBox(height: tokens.space.md),
            _StaggeredChild(
              delay: enter.delayFor(2),
              duration: context.mDur(enter.item.duration),
              child: ABCompareButton(handle: handle),
            ),
            SizedBox(height: tokens.space.xs),
            _StaggeredChild(
              delay: enter.delayFor(3),
              duration: context.mDur(enter.item.duration),
              child: Text(
                AppStrings.feedback.memoHint,
                style: tokens.type.bodySmall?.copyWith(
                  color: tokens.scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 交错入场包装（M-17 非均匀延迟）。
class _StaggeredChild extends StatefulWidget {
  /// 创建交错入场子组件。
  const _StaggeredChild({
    required this.delay,
    required this.duration,
    required this.child,
  });

  /// 入场延迟（已折算当前档位）。
  final Duration delay;

  /// 入场时长（已折算当前档位）。
  final Duration duration;

  /// 被包裹的子组件。
  final Widget child;

  @override
  State<_StaggeredChild> createState() => _StaggeredChildState();
}

class _StaggeredChildState extends State<_StaggeredChild>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
