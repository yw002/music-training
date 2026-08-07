import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_arguments.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_cubit.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_state.dart';
import 'package:interval_ear/features/session_summary/presentation/widgets/mistake_list.dart';
import 'package:interval_ear/features/session_summary/presentation/widgets/summary_header.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';

/// 本组小结页（架构 §2.5 / T20）。
///
/// 路由处理器 `SessionSummaryPage(arguments: arguments as SessionSummaryArguments)`
/// 注入 [SessionSummaryArguments]；本页用 [BlocProvider] 创建 [SessionSummaryCubit]，
/// 把 [TrainingSession] 转成派生统计供子组件消费。错题回放复用 T13 的
/// [WrongAnswerPanel]（经 [MistakeList]），UI 不泄露音高/MIDI/频率。
///
/// 转场为 `M-02`（SharedAxisZ，240+480），由路由层统一处理，本页无需关心。
class SessionSummaryPage extends StatelessWidget {
  /// 创建本组小结页。
  const SessionSummaryPage({required this.arguments, super.key});

  /// 路由参数。
  final SessionSummaryArguments arguments;

  @override
  Widget build(BuildContext context) => BlocProvider<SessionSummaryCubit>(
        create: (_) => SessionSummaryCubit(session: arguments.session),
        child: const _SessionSummaryView(),
      );
}

class _SessionSummaryView extends StatelessWidget {
  const _SessionSummaryView();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      backgroundColor: tokens.scheme.surface,
      appBar: AppBar(
        title: Text(AppStrings.summary.title),
        centerTitle: false,
        automaticallyImplyLeading: true,
      ),
      body: BlocBuilder<SessionSummaryCubit, SessionSummaryState>(
        builder: (BuildContext context, SessionSummaryState state) =>
            _Body(state: state),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final SessionSummaryState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final SessionSummary summary = state.summary;
    return SingleChildScrollView(
      padding: tokens.space.pageInsets(MediaQuery.of(context).size.width).copyWith(
        top: tokens.space.lg,
        bottom: tokens.space.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SummaryHeader(summary: summary),
          SizedBox(height: tokens.space.md),
          _PraiseText(accuracy: summary.accuracy),
          SizedBox(height: tokens.space.lg),
          Text(
            AppStrings.summary.wrongCount,
            style: tokens.type.titleMedium,
          ),
          SizedBox(height: tokens.space.sm),
          MistakeList(mistakes: state.mistakes),
          SizedBox(height: tokens.space.xl),
          _Actions(session: state.session),
        ],
      ),
    );
  }
}

/// 分段鼓励语（按正确率分档）。
class _PraiseText extends StatelessWidget {
  const _PraiseText({required this.accuracy});

  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final String text = accuracy >= 0.8
        ? AppStrings.summary.praiseHigh
        : (accuracy >= 0.5 ? AppStrings.summary.praiseMedium : AppStrings.summary.praiseLow);
    return Text(
      text,
      style: tokens.type.bodyMedium?.copyWith(
        color: tokens.scheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// 底部操作：再来一组（相同 config 重开）/ 查看报告（跳 /report，T21 接）。
class _Actions extends StatelessWidget {
  const _Actions({required this.session});

  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: tokens.space.minTouchTarget,
          child: FilledButton.icon(
            // 验收 ⑤：用相同 config 重开（pushReplacementNamed 替换当前小结页）。
            onPressed: () => Navigator.of(context).pushReplacementNamed(
              RouteNames.training,
              arguments: session.configSnapshot,
            ),
            icon: const Icon(Icons.replay_rounded),
            label: Text(AppStrings.summary.playAgain),
          ),
        ),
        SizedBox(height: tokens.space.sm),
        SizedBox(
          height: tokens.space.minTouchTarget,
          child: OutlinedButton.icon(
            // 验收：查看报告跳 /report；report 路由 T21 才接，当前由占位页兜底不崩。
            onPressed: () => Navigator.of(context).pushNamed(RouteNames.report),
            icon: const Icon(Icons.insights_rounded),
            label: Text(AppStrings.summary.viewReport),
          ),
        ),
      ],
    );
  }
}
