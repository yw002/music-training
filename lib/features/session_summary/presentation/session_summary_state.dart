import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';

/// 本组小结的派生统计（由 [TrainingSession] 重算，便于 UI 直接消费）。
@immutable
class SessionSummary extends Equatable {
  /// 创建派生统计。
  const SessionSummary({
    required this.accuracy,
    required this.duration,
    required this.maxCombo,
    required this.correctCount,
    required this.completedQuestions,
    required this.mistakeCount,
  });

  /// 正确率 [0, 1]（一题未答时为 0，不产生 NaN）。
  final double accuracy;

  /// 训练时长；未结算时为 `null`。
  final Duration? duration;

  /// 本组最长连击。
  final int maxCombo;

  /// 答对题数。
  final int correctCount;

  /// 已完成题数（含加练）。
  final int completedQuestions;

  /// 错题数（与 [TrainingSession.mistakes] 长度一致）。
  final int mistakeCount;

  @override
  List<Object?> get props => <Object?>[
        accuracy,
        duration,
        maxCombo,
        correctCount,
        completedQuestions,
        mistakeCount,
      ];
}

/// 本组小结页状态（架构 §3.1 / T20）。
class SessionSummaryState extends Equatable {
  /// 创建小结状态。
  const SessionSummaryState({
    required this.session,
    required this.summary,
  });

  /// 本组已结算的会话记录。
  final TrainingSession session;

  /// 派生统计（由 [session] 重算）。
  final SessionSummary summary;

  /// 本组答错的作答（含「不确定」），供错题清单回放对比。
  List<TrainingAttempt> get mistakes => session.mistakes;

  @override
  List<Object?> get props => <Object?>[session, summary];
}
