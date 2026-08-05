// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/utils/deterministic_random.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/services/adaptive_question_planner.dart';
import 'package:interval_ear/features/training/domain/services/session_segment.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// T06 验收 §5.2/§5.7：组卷可复现、零历史不崩、分段、二选一强化、加练插题。
void main() {
  final now = DateTime.utc(2026, 5, 1, 12);

  TrainingConfig config({AnswerMode mode = AnswerMode.enabledOnly}) =>
      TrainingConfig(
        enabledIntervals: IntervalCatalog.trainableIds,
        questionCount: 20,
        answerMode: mode,
      );

  group('可复现性（验收 4）', () {
    test('Xorshift32Random(42) 两次组卷题目 ID 序列完全一致', () {
      final snap = StatsSnapshot.empty();
      final a = AdaptiveQuestionPlanner.planSession(
        config: config(),
        snapshot: snap,
        random: Xorshift32Random(seed: 42),
        now: now,
      );
      final b = AdaptiveQuestionPlanner.planSession(
        config: config(),
        snapshot: snap,
        random: Xorshift32Random(seed: 42),
        now: now,
      );
      expect(a.length, 20);
      expect(a.questions.length, b.questions.length);
      for (var i = 0; i < a.questions.length; i++) {
        expect(a.questions[i].questionId, b.questions[i].questionId,
            reason: '第 $i 题 ID 不一致');
        expect(a.questions[i], b.questions[i]);
      }
    });

    test('不同 seed 产生不同题目序列', () {
      final snap = StatsSnapshot.empty();
      final a = AdaptiveQuestionPlanner.planSession(
        config: config(),
        snapshot: snap,
        random: Xorshift32Random(seed: 1),
        now: now,
      );
      final b = AdaptiveQuestionPlanner.planSession(
        config: config(),
        snapshot: snap,
        random: Xorshift32Random(seed: 2),
        now: now,
      );
      expect(a.questions[0].questionId, isNot(b.questions[0].questionId));
    });
  });

  group('零历史不崩（验收 5）', () {
    test('空快照组卷产生满额题目且全部合法', () {
      final plan = AdaptiveQuestionPlanner.planSession(
        config: config(),
        snapshot: StatsSnapshot.empty(),
        random: Xorshift32Random(seed: 42),
        now: now,
      );
      expect(plan.length, 20);
      for (final q in plan.questions) {
        expect(IntervalCatalog.trainableIds.contains(q.correctInterval), isTrue);
        expect(q.answerOptions.length, greaterThanOrEqualTo(2));
        // 选项按半音数升序，与正确答案无关（防位置泄露）。
        final semis = q.answerOptions.map((id) => id.semitones).toList();
        final sorted = List<int>.of(semis)..sort();
        expect(semis, sorted);
      }
    });
  });

  group('分段（§5.7）', () {
    test('buildSegments(20) = 热身4 / 弱项10 / 混合6', () {
      final segments = AdaptiveQuestionPlanner.buildSegments(20);
      expect(segments.length, 3);
      expect(segments[0].type, SessionSegmentType.warmUp);
      expect(segments[0].intervalCount, 4);
      expect(segments[1].type, SessionSegmentType.weakFocus);
      expect(segments[1].intervalCount, 10);
      expect(segments[2].type, SessionSegmentType.mixed);
      expect(segments[2].intervalCount, 6);
    });

    test('segmentAt 正确定位下标', () {
      final segments = AdaptiveQuestionPlanner.buildSegments(20);
      expect(segments[0].type, SessionSegmentType.warmUp);
      expect(AdaptiveQuestionPlanner.planSession(
        config: config(),
        snapshot: StatsSnapshot.empty(),
        random: Xorshift32Random(seed: 9),
        now: now,
      ).segmentAt(0)!.type, SessionSegmentType.warmUp);
    });
  });

  group('二选一强化', () {
    test('focusPair 组卷：全部为二选一且正解在焦点对内', () {
      final pair = IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth);
      final plan = AdaptiveQuestionPlanner.planSession(
        config: config(mode: AnswerMode.binary),
        snapshot: StatsSnapshot.empty(),
        random: Xorshift32Random(seed: 42),
        now: now,
        focusPair: pair,
      );
      expect(plan.length, 20);
      for (final q in plan.questions) {
        expect(q.isBinary, isTrue);
        expect(pair.contains(q.correctInterval), isTrue);
        expect(q.focusPair, pair.key());
      }
    });
  });

  group('加练插题', () {
    test('planExtraDrill 返回 kExtraDrillQuestionCount 道二选一', () {
      final drill = AdaptiveQuestionPlanner.planExtraDrill(
        missed: IntervalId.minorThird,
        config: config(mode: AnswerMode.binary),
        snapshot: StatsSnapshot.empty(),
        random: Xorshift32Random(seed: 5),
        now: now,
        count: 3,
      );
      expect(drill.length, 3);
      for (final q in drill) {
        expect(q.isBinary, isTrue);
      }
    });
  });
}
