import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/free_training/presentation/free_training_cubit.dart';
import 'package:interval_ear/features/free_training/presentation/free_training_state.dart';
import 'package:interval_ear/features/free_training/presentation/widgets/answer_mode_selector.dart';
import 'package:interval_ear/features/free_training/presentation/widgets/direction_selector.dart';
import 'package:interval_ear/features/free_training/presentation/widgets/interval_selector.dart';
import 'package:interval_ear/features/free_training/presentation/widgets/question_count_selector.dart';
import 'package:interval_ear/features/free_training/presentation/widgets/root_selector.dart';
import 'package:interval_ear/features/free_training/presentation/widgets/timbre_selector.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';

/// 自由训练配置页（T19，架构 §2.4）。
///
/// 页面不持有 Cubit：路由层用 `BlocProvider` 注入 [FreeTrainingCubit]，本页只负责
/// 组合各 selector 并把 [TrainingConfig] 经路由参数传给训练页。Cubit 由祖先提供，
/// 与 `HomePage` / `SettingsPage` 的注入方式一致。
class FreeTrainingPage extends StatelessWidget {
  /// 创建自由训练页。
  const FreeTrainingPage({super.key});

  @override
  Widget build(BuildContext context) => const _FreeTrainingView();
}

class _FreeTrainingView extends StatefulWidget {
  const _FreeTrainingView();

  @override
  State<_FreeTrainingView> createState() => _FreeTrainingViewState();
}

class _FreeTrainingViewState extends State<_FreeTrainingView> {
  @override
  void initState() {
    super.initState();
    context.read<FreeTrainingCubit>().load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.freeTraining.title),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: AppStrings.common.save,
              onPressed: () async {
                await context.read<FreeTrainingCubit>().save();
              },
            ),
          ],
        ),
        body: BlocBuilder<FreeTrainingCubit, FreeTrainingState>(
          builder: (BuildContext context, FreeTrainingState state) =>
              _Body(state: state),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final FreeTrainingState state;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final TrainingConfig config = state.config;
    final bool binary = config.answerMode == AnswerMode.binary;
    return ListView(
      padding: tokens.space.pageInsets(MediaQuery.of(context).size.width).copyWith(
            top: tokens.space.lg,
            bottom: tokens.space.xl,
          ),
      children: <Widget>[
        if (!state.isValid) ...<Widget>[
          _ErrorBanner(issues: state.validation.errors),
          SizedBox(height: tokens.space.md),
        ],
        _ConfigSection(
          title: AppStrings.freeTraining.intervalSection,
          subtitle:
              binary ? AppStrings.freeTraining.binaryNeedsExactlyTwo : null,
          child: IntervalSelector(
            selected: config.enabledIntervals,
            onToggle: context.read<FreeTrainingCubit>().toggleInterval,
            maxSelectable: binary ? AppConfig.binaryOptionCount : null,
          ),
        ),
        _ConfigSection(
          title: AppStrings.freeTraining.directionSection,
          child: DirectionSelector(
            value: config.direction,
            onChanged: context.read<FreeTrainingCubit>().setDirection,
          ),
        ),
        _ConfigSection(
          title: AppStrings.freeTraining.rootSection,
          child: RootSelector(
            value: config.rootMode,
            onChanged: context.read<FreeTrainingCubit>().setRootMode,
          ),
        ),
        _ConfigSection(
          title: AppStrings.freeTraining.timbreSection,
          child: TimbreSelector(
            value: config.timbreMode,
            onChanged: context.read<FreeTrainingCubit>().setTimbreMode,
          ),
        ),
        _ConfigSection(
          title: AppStrings.freeTraining.questionCountSection,
          child: QuestionCountSelector(
            value: config.questionCount,
            onChanged: context.read<FreeTrainingCubit>().setQuestionCount,
          ),
        ),
        _ConfigSection(
          title: AppStrings.freeTraining.answerModeBinary,
          child: AnswerModeSelector(
            value: config.answerMode,
            onChanged: context.read<FreeTrainingCubit>().setAnswerMode,
          ),
        ),
        _InfoCard(),
        SizedBox(height: tokens.space.lg),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: context.read<FreeTrainingCubit>().resetToDefault,
              child: Text(AppStrings.freeTraining.resetToDefault),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => _onStart(context),
              child: Text(AppStrings.freeTraining.startTraining),
            ),
          ],
        ),
      ],
    );
  }

  void _onStart(BuildContext context) async {
    final FreeTrainingCubit cubit = context.read<FreeTrainingCubit>();
    if (cubit.start()) {
      await cubit.save();
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushNamed(
        RouteNames.training,
        arguments: cubit.state.config,
      );
    }
  }
}

/// 把 [ValidationIssue] 翻译成面向用户的提示文案（文案集中在 [AppStrings]）。
String _messageFor(ValidationIssue issue) {
  final FreeTrainingStrings strings = AppStrings.freeTraining;
  switch (issue.code) {
    case TrainingConfig.codeTooFewIntervals:
      return strings.needAtLeastTwoIntervals;
    case TrainingConfig.codeBinaryNeedsExactlyTwo:
      return strings.binaryNeedsExactlyTwo;
    case TrainingConfig.codeQuestionCountOutOfRange:
      return strings.questionCountOutOfRange;
    case TrainingConfig.codeNoteDurationOutOfRange:
      return strings.noteDurationOutOfRange;
    case TrainingConfig.codeNoteGapOutOfRange:
      return strings.noteGapOutOfRange;
    default:
      return strings.invalidConfig;
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.issues});

  final List<ValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final String message =
        issues.map(_messageFor).join(AppStrings.common.issueSeparator);
    return Container(
      padding: EdgeInsets.all(tokens.space.md),
      decoration: BoxDecoration(
        color: tokens.color.warning.container,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: tokens.color.warning.onContainer),
          SizedBox(width: tokens.space.sm),
          Expanded(
            child: Text(
              message,
              style: tokens.type.bodyMedium?.copyWith(
                color: tokens.color.warning.onContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  const _ConfigSection({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: tokens.type.titleMedium),
          if (subtitle != null) ...<Widget>[
            SizedBox(height: tokens.space.xs),
            Text(
              subtitle!,
              style: tokens.type.bodySmall?.copyWith(
                color: tokens.scheme.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: tokens.space.sm),
          child,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Card(
      child: Padding(
        padding: tokens.space.cardInsets,
        child: Text(
          AppStrings.freeTraining.allVsTodayHint,
          style: tokens.type.bodyMedium?.copyWith(
            color: tokens.scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
