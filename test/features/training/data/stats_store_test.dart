// 统计存储与重建（T16 验收 1 / T10 StatsSnapshot.empty 可用性）。
//
// 覆盖点：
//  - StatsSnapshot.empty() 可安全使用（非 const 冻结，可被 withAttempt 推进）；
//  - StatsStore.applyAttempt / applySession 增量更新且不可变；
//  - persist → 重新加载 与落盘前快照完全一致（往返一致）；
//  - StatsStore.rebuildFromAttempts 与增量累积结果一致（无第二个真相）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/storage/json_file_store.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';
import 'package:interval_ear/features/training/data/stats_store.dart';

TrainingAttempt _attempt(IntervalId correct, IntervalId selected,
        DateTime createdAt, {bool uncertain = false}) =>
    TrainingAttempt(
      attemptId: 'a_${createdAt.microsecondsSinceEpoch}',
      sessionId: 's',
      questionId: 'q',
      correctInterval: correct,
      selectedInterval: uncertain ? null : selected,
      isUncertain: uncertain,
      replayCount: 0,
      responseDuration: const Duration(milliseconds: 100),
      direction: PlaybackDirection.ascending,
      timbre: Timbre.keyboard,
      rootMode: RootMode.limitedRandom,
      rootMidiNote: 60,
      answerMode: AnswerMode.enabledOnly,
      createdAt: createdAt,
    );

void main() {
  group('StatsSnapshot / StatsStore（T16 / T10）', () {
    test('StatsSnapshot.empty() 可安全使用（非 const 冻结）', () {
      final empty = StatsSnapshot.empty();
      expect(empty.isEmpty, isTrue);
      expect(empty.totalQuestions, 0);

      // 推进不抛、且返回新快照（原空快照不变）。
      final next = empty.withAttempt(
        _attempt(IntervalId.minorSecond, IntervalId.minorSecond,
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
      );
      expect(empty.totalQuestions, 0); // 原对象不可变。
      expect(next.totalQuestions, 1);
    });

    test('applyAttempt 增量更新且不可变；applySession 累计会话数', () {
      final store = StatsStore(fileStore: JsonFileStore(dir: Directory.systemTemp));
      final t0 = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

      store.applyAttempt(_attempt(IntervalId.minorSecond, IntervalId.minorSecond,
          t0.add(const Duration(seconds: 1))));
      expect(store.snapshot.totalQuestions, 1);

      store.applyAttempt(_attempt(IntervalId.majorSeventh, IntervalId.majorSeventh,
          t0.add(const Duration(seconds: 2))));
      expect(store.snapshot.totalQuestions, 2);

      final session = TrainingSession(
        sessionId: 's',
        trainingMode: TrainingMode.daily,
        startedAt: t0,
        finishedAt: t0.add(const Duration(minutes: 5)),
        totalQuestions: 5,
        completedQuestions: 2,
        correctCount: 2,
        configSnapshot: TrainingConfig.defaults,
      );
      store.applySession(session);
      expect(store.snapshot.totalSessions, 1);
    });

    test('persist → 重新加载 与落盘前快照完全一致', () async {
      final dir = Directory.systemTemp.createTempSync('stats_store_rt_');
      final store = StatsStore(fileStore: JsonFileStore(dir: dir));
      final t0 = DateTime.utc(2026, 1, 1);
      store.applyAttempt(_attempt(IntervalId.minorSecond, IntervalId.minorSecond,
          t0.add(const Duration(seconds: 1))));
      store.applyAttempt(_attempt(IntervalId.majorSeventh, IntervalId.majorSeventh,
          t0.add(const Duration(seconds: 2))));
      final before = store.snapshot;

      await store.persist();

      final store2 = StatsStore(fileStore: JsonFileStore(dir: dir));
      await store2.init();
      expect(store2.snapshot, before);

      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('rebuildFromAttempts 与增量累积结果一致', () {
      final t0 = DateTime.utc(2026, 2, 1);
      final attempts = <TrainingAttempt>[
        _attempt(IntervalId.minorSecond, IntervalId.minorSecond,
            t0.add(const Duration(seconds: 1))),
        _attempt(IntervalId.majorSeventh, IntervalId.minorSecond,
            t0.add(const Duration(seconds: 2))),
        _attempt(IntervalId.minorThird, IntervalId.minorThird,
            t0.add(const Duration(seconds: 3)), uncertain: true),
      ];

      // 增量路径。
      var incremental = StatsSnapshot.empty();
      for (final a in attempts) {
        incremental = incremental.withAttempt(a);
      }

      // 全量重建路径（StatRepo 的重建契约）。
      final rebuilt = StatsSnapshot.rebuildFromAttempts(attempts, const <TrainingSession>[]);

      expect(rebuilt, incremental);
      expect(rebuilt.totalQuestions, 3);
    });
  });
}
