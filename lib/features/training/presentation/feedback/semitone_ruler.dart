import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/presentation/feedback/feedback_tokens.dart';
import 'package:interval_ear/features/training/presentation/feedback/semitone_ruler_painter.dart';

/// 半音尺对比条（`M-18` compare.semitoneRuler）。
///
/// 用可视化长度直观呈现「正确音程 vs 你选的音程」的半音差距。入场时长 =
/// 半音数 × 40ms 钳 320–560ms（[FeedbackTokens.semitoneRulerDuration]，已折算
/// 当前档位）；`reduced`/`off` 档下仍**保留终态**（PRD §3.10）。
class SemitoneRuler extends StatelessWidget {
  /// 创建半音尺。
  const SemitoneRuler({
    required this.correctInterval,
    required this.selectedInterval,
    super.key,
  });

  /// 正确音程。
  final IntervalId correctInterval;

  /// 用户所选音程（不确定为 `null` 时用正确音程，避免空尺）。
  final IntervalId? selectedInterval;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final level = context.motionLevel;
    final selected = selectedInterval ?? correctInterval;
    const maxSemis = IntervalId.maxSemitones;
    final span = correctInterval.semitones > selected.semitones
        ? correctInterval.semitones
        : selected.semitones;
    final duration = FeedbackTokens.semitoneRulerDuration(level, span);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.feedback.semitoneRulerTitle,
          style: tokens.type.labelMedium
              ?.copyWith(color: tokens.scheme.onSurface.withValues(alpha: 0.8)),
        ),
        SizedBox(height: tokens.space.xxs),
        SizedBox(
          height: 72,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => CustomPaint(
              painter: SemitoneRulerPainter(
                correctSemitones: correctInterval.semitones,
                selectedSemitones: selected.semitones,
                correctColor: tokens.color.success.base,
                selectedColor: tokens.color.warning.base,
                progress: progress,
                maxSemitones: maxSemis,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        SizedBox(height: tokens.space.xxs),
        Text(
          _deltaLabel(correctInterval, selected),
          style: tokens.type.bodySmall
              ?.copyWith(color: tokens.scheme.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  String _deltaLabel(IntervalId correct, IntervalId selected) {
    final delta = (correct.semitones - selected.semitones).abs();
    if (delta == 0) {
      return AppStrings.feedback.sameSemitones;
    }
    final correctName = IntervalCatalog.nameOf(correct);
    final selectedName = IntervalCatalog.nameOf(selected);
    return '${AppStrings.feedback.correctAnswer}: $correctName · '
        '${AppStrings.feedback.yourAnswer}: $selectedName';
  }
}
