import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// 反馈区动效 token 取用助手（架构 §3.5 / T13）。
///
/// 直接引用 `AppMotionTokens.standard()` 的常量取值（不依赖 `BuildContext`），
/// 便于纯逻辑处（如时长计算、交错延迟）复用 M-15~M-20 的权威参数。页面渲染仍应
/// 优先走 `context.tokens.motion.feedback.*`，本类只服务于「非 widget 上下文」场景。
abstract final class FeedbackTokens {
  const FeedbackTokens._();

  /// `M-17` 错题面板的非均匀交错入场（80/140/200/280）。
  static MotionStaggerSpec get wrongPanelEnter =>
      AppMotionTokens.standard().feedback.wrongPanelEnter;

  /// `M-18` 半音尺绘制时长：半音数 × 40ms，钳制到 320–560ms，并折算当前档位。
  static Duration semitoneRulerDuration(MotionLevel level, int semitones) =>
      AppMotionTokens.standard().feedback.semitoneRuler.effectiveFor(
        level,
        semitones,
      );

  /// `M-15` 答对整段时长。
  static Duration get correct => AppMotionTokens.standard().feedback.correct.duration;

  /// `M-15` 中阻塞用户输入的 180ms 段。
  static Duration get correctBlocking =>
      AppMotionTokens.standard().feedback.correctBlocking.duration;

  /// `M-16` 答错时长。
  static Duration get wrong => AppMotionTokens.standard().feedback.wrong.duration;

  /// `M-20` 不确定中性反馈时长。
  static Duration get uncertain =>
      AppMotionTokens.standard().feedback.uncertain.duration;

  /// `M-19` A/B 对比按钮的进度环（时长由音频序列驱动，此处取兜底）。
  static Duration get abButton =>
      AppMotionTokens.standard().feedback.abButton.duration;
}
