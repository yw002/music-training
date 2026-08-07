import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/presentation/feedback/wrong_answer_panel.dart';

/// 错题清单（架构 §2.5 / T20 验收 ④）。
///
/// **复用 T13 的 [WrongAnswerPanel]**（内嵌 [FeedbackController]）逐条做对比播放，
/// **不重复实现**反馈逻辑，也不泄露音高/MIDI/频率：回放完全走
/// [FeedbackController.playComparison] 单缓冲。每条错题由 [TrainingAttempt] 重建出
/// 题目描述 [IntervalQuestion]——仅用于合成对比音频，UI 仍只展示音程名 / 半音数。
///
/// 注：跨 feature 复用 `training/presentation/feedback` 是架构 §3.3 / §4.1 明确
/// 约定的「mistake_list 复用 FeedbackController」之处，是本批次唯一被设计允许的
/// presentation 跨 feature 引用（一般情形下 `features/*/presentation` 互不引用）。
class MistakeList extends StatelessWidget {
  /// 创建错题清单。
  const MistakeList({required this.mistakes, super.key});

  /// 本组答错的作答（含「不确定」）。
  final List<TrainingAttempt> mistakes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final AudioService audio = context.read<AudioService>();
    if (mistakes.isEmpty) {
      return _EmptyMistakes();
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: mistakes.length,
      separatorBuilder: (BuildContext _, int index) =>
          SizedBox(height: tokens.space.md),
      itemBuilder: (BuildContext context, int index) => _MistakeTile(
        index: index,
        attempt: mistakes[index],
        audio: audio,
      ),
    );
  }
}

/// 单条错题：标题行 + 复用 [WrongAnswerPanel] 做对比播放。
class _MistakeTile extends StatelessWidget {
  const _MistakeTile({
    required this.index,
    required this.attempt,
    required this.audio,
  });

  final int index;
  final TrainingAttempt attempt;
  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final String intervalName = IntervalCatalog.nameOf(attempt.correctInterval);
    final String tag = attempt.isUncertain
        ? AppStrings.feedback.uncertain
        : AppStrings.feedback.wrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              attempt.isUncertain
                  ? Icons.help_outline_rounded
                  : Icons.error_outline_rounded,
              size: 18,
              color: tokens.color.warning.base,
            ),
            SizedBox(width: tokens.space.xs),
            Expanded(
              child: Text(
                '${AppStrings.summary.wrongCount} ${index + 1} · $intervalName',
                style: tokens.type.labelLarge?.copyWith(
                  color: tokens.scheme.onSurface,
                ),
              ),
            ),
            Text(
              tag,
              style: tokens.type.bodySmall?.copyWith(
                color: tokens.color.warning.onContainer,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.space.xs),
        WrongAnswerPanel(
          audio: audio,
          question: questionFromMistake(attempt),
          attempt: attempt,
        ),
      ],
    );
  }
}

/// 无错题时的空态。
class _EmptyMistakes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: tokens.color.success.base,
            ),
            SizedBox(height: tokens.space.sm),
            Text(
              AppStrings.common.empty,
              style: tokens.type.bodyMedium?.copyWith(
                color: tokens.scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 由 [TrainingAttempt] 重建题目描述，仅用于合成对比播放音频（反馈逻辑仍由
/// [FeedbackController] 负责，UI 不读音高/MIDI/频率）。
IntervalQuestion questionFromMistake(TrainingAttempt attempt) {
  final int root = attempt.rootMidiNote;
  final int semitones = attempt.correctInterval.semitones;
  final int target = switch (attempt.direction) {
    PlaybackDirection.descending => root - semitones,
    PlaybackDirection.harmonic => root + semitones,
    PlaybackDirection.ascending => root + semitones,
  };
  final Set<IntervalId> options = <IntervalId>{attempt.correctInterval};
  final IntervalId? selected = attempt.selectedInterval;
  if (selected != null) {
    options.add(selected);
  }
  return IntervalQuestion(
    questionId: attempt.questionId,
    correctInterval: attempt.correctInterval,
    rootMidiNote: root,
    targetMidiNote: target,
    direction: attempt.direction,
    timbre: attempt.timbre,
    rootMode: attempt.rootMode,
    answerOptions: IntervalCatalog.sorted(options),
    createdAt: attempt.createdAt,
    bucket: attempt.bucket,
    focusPair: attempt.focusPair,
  );
}
