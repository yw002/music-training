import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/features/session_summary/presentation/session_summary_cubit.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';

import '../test_support.dart';

void main() {
  test('正确率/用时/最长连击/错题数 由会话记录重算', () {
    final mistakes = <TrainingAttempt>[
      makeAttempt(
        correct: IntervalId.perfectFifth,
        selected: IntervalId.perfectFourth,
      ),
      makeAttempt(correct: IntervalId.majorThird, uncertain: true),
    ];
    final session = makeSession(
      correctCount: 8,
      completedQuestions: 10,
      maxCombo: 5,
      mistakes: mistakes,
      elapsed: const Duration(seconds: 90),
    );

    final cubit = SessionSummaryCubit(session: session);
    final summary = cubit.state.summary;

    expect(summary.accuracy, closeTo(0.8, 1e-9));
    expect(summary.duration, const Duration(seconds: 90));
    expect(summary.maxCombo, 5);
    expect(summary.correctCount, 8);
    expect(summary.completedQuestions, 10);
    expect(summary.mistakeCount, 2);
    expect(cubit.state.mistakes, mistakes);
    cubit.close();
  });

  test('零完成题数时正确率为 0 且不产生 NaN', () {
    final session = makeSession(
      correctCount: 0,
      completedQuestions: 0,
      maxCombo: 0,
      mistakes: const <TrainingAttempt>[],
    );

    final cubit = SessionSummaryCubit(session: session);

    expect(cubit.state.summary.accuracy, 0.0);
    expect(cubit.state.summary.accuracy.isNaN, isFalse);
    expect(cubit.state.summary.mistakeCount, 0);
    cubit.close();
  });

  test('未结算会话时用时为 null', () {
    final session = makeSession(
      mistakes: const <TrainingAttempt>[],
    );

    final cubit = SessionSummaryCubit(session: session);

    expect(cubit.state.summary.duration, isNull);
    cubit.close();
  });
}
