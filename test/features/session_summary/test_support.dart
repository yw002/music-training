import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';

/// T20 测试共享构造助手（仅 test 使用，不参与 lib 分析）。
///
/// 用固定 seed 的数据构造 [TrainingSession] / [TrainingAttempt]，便于断言派生统计
/// 与错题清单回放。时间全部用 `DateTime.fromMillisecondsSinceEpoch(0, isUtc:true)`
/// 基线，避免 `DateTime.now()`。

/// 构造一条作答记录。
TrainingAttempt makeAttempt({
  required IntervalId correct,
  IntervalId? selected,
  bool uncertain = false,
  int rootMidi = 60,
}) =>
    TrainingAttempt(
      attemptId: 'a-${correct.storageId}-${selected?.storageId ?? 'none'}',
      sessionId: 's1',
      questionId: 'q-${correct.storageId}',
      correctInterval: correct,
      selectedInterval: selected,
      isUncertain: uncertain,
      replayCount: 0,
      responseDuration: Duration.zero,
      direction: PlaybackDirection.ascending,
      timbre: Timbre.keyboard,
      rootMode: RootMode.fixed,
      rootMidiNote: rootMidi,
      answerMode: AnswerMode.allIntervals,
      bucket: QuestionBucket.randomProbe,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

/// 构造一个已结算会话记录。
TrainingSession makeSession({
  int correctCount = 8,
  int completedQuestions = 10,
  int maxCombo = 5,
  required List<TrainingAttempt> mistakes,
  Duration? elapsed,
}) =>
    TrainingSession(
      sessionId: 's1',
      trainingMode: TrainingMode.daily,
      startedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      finishedAt: elapsed == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(elapsed.inMilliseconds, isUtc: true),
      totalQuestions: 10,
      completedQuestions: completedQuestions,
      correctCount: correctCount,
      maxCombo: maxCombo,
      configSnapshot: TrainingConfig.defaults,
      mistakes: mistakes,
    );
