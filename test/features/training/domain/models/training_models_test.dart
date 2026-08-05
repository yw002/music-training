// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';

/// T04 验收：13 个音程 + 持久化 + JSON 往返 + 前向兼容枚举。
void main() {
  group('IntervalId', () {
    test('13 个音程全部可训练，半音数 0..12 连续', () {
      final ids = IntervalCatalog.trainableIds;
      expect(ids.length, 13);
      final semitones = ids.map((id) => id.semitones).toList();
      expect(semitones, orderedEquals(<int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]));
    });

    test('storageId 往返稳定', () {
      for (final id in IntervalCatalog.allIds) {
        final back = IntervalId.fromStorageId(id.storageId);
        expect(back, id);
      }
    });

    test('未知 storageId 降级为 defaultValue 而非抛异常', () {
      expect(IntervalId.fromStorageId('nope'), IntervalId.defaultValue);
      expect(IntervalId.tryFromStorageId('nope'), isNull);
    });

    test('bySemitones / semitoneDistanceTo', () {
      expect(IntervalId.fromSemitones(7), IntervalId.perfectFifth);
      expect(IntervalId.minorThird.semitoneDistanceTo(IntervalId.majorThird), 1);
    });
  });

  group('IntervalPair 规范化', () {
    test('顺序无关：m6|M6 == M6|m6', () {
      final a = IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth);
      final b = IntervalPair(IntervalId.majorSixth, IntervalId.minorSixth);
      expect(a.normalized().key(), b.normalized().key());
      expect(a.normalized(), b.normalized());
    });

    test('key() 与 tryFromKey 往返', () {
      final pair = IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth);
      final round = IntervalPair.tryFromKey(pair.key());
      expect(round, isNotNull);
      expect(round!.key(), pair.key());
    });
  });

  group('枚举前向兼容', () {
    test('所有枚举未知值降级到 defaultValue', () {
      expect(PlaybackDirection.fromStorageId('???'),
          PlaybackDirection.defaultValue);
      expect(RootMode.fromStorageId('???'), RootMode.defaultValue);
      expect(Timbre.fromStorageId('???'), Timbre.defaultValue);
      expect(AnswerMode.fromStorageId('???'), AnswerMode.defaultValue);
      expect(TrainingMode.fromStorageId('???'), TrainingMode.defaultValue);
      expect(QuestionBucket.fromStorageId('???'), QuestionBucket.defaultValue);
      expect(MasteryBucket.fromStorageId('???'), MasteryBucket.defaultValue);
    });
  });

  group('TrainingConfig JSON', () {
    test('往返等价', () {
      final config = TrainingConfig(
        enabledIntervals: <IntervalId>{
          IntervalId.minorThird,
          IntervalId.majorThird,
        },
        direction: DirectionMode.randomMixed,
        rootMode: RootMode.fullRandom,
        timbreMode: TimbreMode.random,
        questionCount: 12,
        answerMode: AnswerMode.binary,
      );
      final back = TrainingConfig.fromJson(config.toJson());
      expect(back, config);
      expect(back.enabledIntervals, config.enabledIntervals);
      expect(back.answerMode, AnswerMode.binary);
    });

    test('validate 拒绝少于 2 个音程', () {
      final broken = TrainingConfig(
        enabledIntervals: <IntervalId>{IntervalId.minorThird},
      );
      expect(broken.validate().isValid, isFalse);
    });

    test('binary 模式要求恰好 2 个音程', () {
      final broken = TrainingConfig(
        enabledIntervals: IntervalCatalog.trainableIds,
        answerMode: AnswerMode.binary,
      );
      final issues = broken.validate();
      expect(issues.isValid, isFalse);
    });
  });

  group('TrainingAttempt / TrainingSession', () {
    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);

    test('TrainingAttempt 不确定不计入正确', () {
      final attempt = TrainingAttempt(
        attemptId: 'a1',
        sessionId: 's1',
        questionId: 'q1',
        correctInterval: IntervalId.minorThird,
        selectedInterval: null,
        isUncertain: true,
        replayCount: 0,
        responseDuration: const Duration(milliseconds: 123),
        direction: PlaybackDirection.ascending,
        timbre: Timbre.keyboard,
        rootMode: RootMode.limitedRandom,
        rootMidiNote: 60,
        answerMode: AnswerMode.enabledOnly,
        createdAt: now,
      );
      expect(attempt.isCorrect, isFalse);
      expect(attempt.countsTowardConfusion, isFalse);
    });

    test('TrainingAttempt JSON 往返', () {
      final attempt = TrainingAttempt(
        attemptId: 'a1',
        sessionId: 's1',
        questionId: 'q1',
        correctInterval: IntervalId.perfectFifth,
        selectedInterval: IntervalId.perfectFourth,
        isUncertain: false,
        replayCount: 2,
        responseDuration: const Duration(milliseconds: 555),
        direction: PlaybackDirection.harmonic,
        timbre: Timbre.plucked,
        rootMode: RootMode.fullRandom,
        rootMidiNote: 67,
        answerMode: AnswerMode.binary,
        bucket: QuestionBucket.weakPair,
        focusPair: 'm6|M6',
        createdAt: now,
      );
      final back = TrainingAttempt.fromJson(attempt.toJson());
      expect(back, attempt);
      expect(back.correctInterval, IntervalId.perfectFifth);
      expect(back.focusPair, 'm6|M6');
    });

    test('TrainingSession 未结算 duration 为 null', () {
      final session = TrainingSession(
        sessionId: 's1',
        trainingMode: TrainingMode.daily,
        startedAt: now,
        totalQuestions: 10,
        configSnapshot: TrainingConfig.defaults,
      );
      expect(session.isFinished(), isFalse);
      expect(session.duration, isNull);
      expect(session.accuracy, 0);
    });

    test('TrainingSession JSON 往返且 duration 可算', () {
      final finished = DateTime.utc(2026, 1, 2, 3, 10, 5);
      final session = TrainingSession(
        sessionId: 's1',
        trainingMode: TrainingMode.binaryDrill,
        startedAt: now,
        finishedAt: finished,
        totalQuestions: 10,
        completedQuestions: 10,
        correctCount: 8,
        focusPair: IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth),
        presetId: 'basic',
        configSnapshot: TrainingConfig.defaults,
      );
      final back = TrainingSession.fromJson(session.toJson());
      expect(back, session);
      expect(back.accuracy, 0.8);
      expect(back.duration, const Duration(minutes: 6));
      expect(back.focusPair!.key(), 'm6|M6');
    });
  });
}
