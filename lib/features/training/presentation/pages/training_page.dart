import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_arguments.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_cubit.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_state.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_view_model.dart';
import 'package:interval_ear/features/training/presentation/feedback/correct_flash.dart';
import 'package:interval_ear/features/training/presentation/feedback/uncertain_panel.dart';
import 'package:interval_ear/features/training/presentation/feedback/wrong_answer_panel.dart';
import 'package:interval_ear/features/training/presentation/widgets/answer_grid.dart';
import 'package:interval_ear/features/training/presentation/widgets/celebration_layer.dart';
import 'package:interval_ear/features/training/presentation/widgets/chapter_advance_overlay.dart';
import 'package:interval_ear/features/training/presentation/widgets/combo_badge.dart';
import 'package:interval_ear/features/training/presentation/widgets/replay_button.dart';
import 'package:interval_ear/features/training/presentation/widgets/training_app_bar.dart';
import 'package:interval_ear/features/training/presentation/widgets/uncertain_button.dart';
import 'package:interval_ear/features/training/presentation/widgets/visualizer/playback_visualizer.dart';

/// 训练页（架构 §3.5 / T11 骨架 + T12/T13/T14 装配）。
///
/// 职责：纯 UI 装配。所有领域逻辑委托 [TrainingCubit]；可视化/反馈/庆祝均走既有
/// widget，并通过 `context.tokens` 取设计令牌、通过 `MotionScope` 取动效档位。
///
/// **防泄露护栏**：答案网格 `AnswerGrid` 只接收 `vm.options`（作答前全为
/// 非正确/非选中），因此 `ready` 与 `awaitingAnswer` 下答案区逐像素一致
/// （§5.6 golden）。播放可视化完全由 `EnvelopeSampler` 驱动，不触碰音高。
class TrainingPage extends StatefulWidget {
  /// 创建训练页。
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  @override
  void initState() {
    super.initState();
    // 页面挂载即启动一组训练（组卷 → 播第一题）。
    context.read<TrainingCubit>().start();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      backgroundColor: tokens.scheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: BlocBuilder<TrainingCubit, TrainingState>(
          builder: (context, state) {
            final vm = TrainingViewModel.from(state);
            return TrainingAppBar(
              title: AppStrings.training.title,
              progressLabel: vm.progressLabel,
              progress: state is ActiveQuestionState
                  ? state.progress
                  : (state is TrainingFinished
                      ? 1.0
                      : 0.0),
              comboLabel: vm.comboLabel,
              onAbort: () => context.read<TrainingCubit>().abort(),
            );
          },
        ),
      ),
      body: BlocBuilder<TrainingCubit, TrainingState>(
        builder: (context, state) => _Body(state: state),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final TrainingState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vm = TrainingViewModel.from(state);
    final cubit = context.read<TrainingCubit>();
    final audio = context.read<AudioService>();

    if (state is TrainingInitial || state is TrainingLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is TrainingFinished) {
      final finished = state as TrainingFinished;
      return _FinishedView(state: finished);
    }

    final question = vm.question;
    final visualizerStyle = cubit.settings.visualizerStyle;
    final playbackId = vm.playback?.playbackId ?? 0;
    final timbre = question?.timbre ?? Timbre.keyboard;

    final isAnswered = vm.showFeedback;
    final isCorrect = isAnswered &&
        state is TrainingAnswered &&
        (state as TrainingAnswered).isCorrect;
    final isUncertain = isAnswered &&
        state is TrainingAnswered &&
        (state as TrainingAnswered).isUncertain;

    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          padding: tokens.space.pageInsets(
            MediaQuery.of(context).size.width,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 8),
              Center(
                child: PlaybackVisualizer(
                  audio: audio,
                  playbackId: playbackId,
                  timbre: timbre,
                  style: visualizerStyle,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  vm.promptLabel,
                  style: tokens.type.titleMedium
                      ?.copyWith(color: tokens.scheme.onSurface),
                ),
              ),
              const SizedBox(height: 16),
              AnswerGrid(
                options: vm.options,
                enabled: vm.canAnswer,
                onSelect: (id) => cubit.submitAnswer(id),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: UncertainButton(
                      enabled: vm.canAnswer,
                      onPressed: () => cubit.submitUncertain(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ReplayButton(
                    enabled: vm.canReplay && vm.canAnswer,
                    onPressed: () => cubit.replay(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isAnswered && !isCorrect && !isUncertain)
                WrongAnswerPanel(
                  audio: audio,
                  question: (state as TrainingAnswered).question,
                  attempt: (state as TrainingAnswered).attempt,
                ),
              if (isAnswered && isUncertain) const UncertainPanel(),
              const SizedBox(height: 16),
              if (isAnswered)
                SizedBox(
                  height: tokens.space.minTouchTarget,
                  child: ElevatedButton(
                    onPressed: () => cubit.next(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.scheme.primary,
                      foregroundColor: tokens.scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radius.md),
                      ),
                    ),
                    child: Text(
                      vm.isLast ? AppStrings.common.done : AppStrings.training.next,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        // 连击徽章（右上角悬浮）。
        Positioned(
          top: 12,
          right: 16,
          child: ComboBadge(combo: vm.combo),
        ),
        // 答对闪光（仅答对）。
        if (isAnswered && isCorrect) const CorrectFlash(),
        // 庆祝粒子层。
        CelebrationLayer(
          combo: vm.combo,
          level: cubit.settings.celebrationLevel,
          color: tokens.color.warning.base,
        ),
        // 章节推进浮层（M-23）：仅在触发章节解锁时短暂展示。
        if (state is TrainingFinished && (state as TrainingFinished).chapterAdvanced)
          ChapterAdvanceOverlay(chapterName: (state as TrainingFinished).chapterName),
      ],
    );
  }
}

class _FinishedView extends StatelessWidget {
  const _FinishedView({required this.state});

  final TrainingFinished state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accuracy = (state.session.accuracy * 100).round();
    return Center(
      child: Padding(
        padding: tokens.space.pageInsets(
          MediaQuery.of(context).size.width,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: tokens.color.success.base,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.summary.title,
              style: tokens.type.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${AppStrings.summary.accuracy}：${AppStrings.unit.percent(accuracy)}',
              style: tokens.type.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${AppStrings.summary.bestCombo}：${state.session.maxCombo}',
              style: tokens.type.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (state.chapterAdvanced)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Chip(
                  label: Text(AppStrings.training.chapterAdvance('')),
                  backgroundColor: tokens.color.success.container,
                ),
              ),
            SizedBox(
              height: tokens.space.minTouchTarget,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed(
                  RouteNames.sessionSummary,
                  arguments: SessionSummaryArguments(session: state.session),
                ),
                child: Text(AppStrings.summary.viewSummary),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: tokens.space.minTouchTarget,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(AppStrings.common.back),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
