import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/features/session_summary/presentation/session_summary_state.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';

/// 本组小结状态机（架构 §3.1 / T20）。
///
/// 输入 [TrainingSession]（经路由参数注入），对外暴露重算后的 [SessionSummary]。
/// 小结是纯派生视图，无副作用、无异步，构造即产出终态。
class SessionSummaryCubit extends Cubit<SessionSummaryState> {
  /// 创建小结 Cubit。
  SessionSummaryCubit({required TrainingSession session})
      : super(
          SessionSummaryState(
            session: session,
            summary: _summarize(session),
          ),
        );

  /// 由会话记录重算派生统计。
  static SessionSummary _summarize(TrainingSession session) => SessionSummary(
        accuracy: session.accuracy,
        duration: session.duration,
        maxCombo: session.maxCombo,
        correctCount: session.correctCount,
        completedQuestions: session.completedQuestions,
        mistakeCount: session.mistakes.length,
      );
}
