// 训练仓储实现与数据恢复（T16 验收 1/2/3/4/6）。
//
// 覆盖点：
//  - JSONL 是唯一真相源：recordAttempt 只做 JSONL 追加，finishSession 才落盘
//    stats.json（增量更新，不每条重写）；
//  - 按月分片（attempts_YYYY-MM.jsonl），跨月落到不同文件；
//  - stats.json 删除后可由 JSONL 流水的全量重算完全还原（与增量结果一致）；
//  - 损坏 JSONL 行触发 RecoveryReport：记录 corruptedLines 但保留有效 attempts；
//  - SettingsRepository 往返 AppSettings（领域层 ThemePreference，非 flutter ThemeMode）；
//  - 全量重算 10000 条耗时 < 2s（核心性能契约）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/storage/jsonl_appender.dart';
import 'package:interval_ear/features/training/data/attempt_dto.dart';
import 'package:interval_ear/features/training/data/settings_repository_impl.dart';
import 'package:interval_ear/features/training/data/session_dto.dart';
import 'package:interval_ear/features/training/data/stats_rebuilder.dart';
import 'package:interval_ear/features/training/data/training_repository_impl.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/repositories/recovery_report.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

TrainingAttempt _attempt(
  String sessionId,
  IntervalId correct,
  IntervalId selected,
  DateTime createdAt, {
  bool uncertain = false,
}) =>
    TrainingAttempt(
      attemptId: 'a_${createdAt.microsecondsSinceEpoch}',
      sessionId: sessionId,
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

TrainingSession _session(String id, DateTime started, {bool finished = true}) =>
    TrainingSession(
      sessionId: id,
      trainingMode: TrainingMode.daily,
      startedAt: started,
      finishedAt: finished ? started.add(const Duration(minutes: 5)) : null,
      totalQuestions: 5,
      configSnapshot: TrainingConfig(
        enabledIntervals: <IntervalId>{
          IntervalId.minorSecond,
          IntervalId.majorSeventh,
        },
      ),
    );

void main() {
  group('TrainingRepositoryImpl（T16 验收 1/3/4）', () {
    late Directory dir;
    late TrainingRepositoryImpl repo;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('trepo_test_');
      repo = TrainingRepositoryImpl(dataDir: dir);
    });

    tearDown(() async {
      await repo.dispose();
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('recordAttempt 仅做 JSONL 追加，stats.json 不立即落盘（增量更新）', () async {
      final t = DateTime.utc(2026, 1, 10);
      await repo.recordAttempt(
        _attempt('s1', IntervalId.minorSecond, IntervalId.minorSecond, t),
      );
      await repo.recordAttempt(
        _attempt('s1', IntervalId.minorSecond, IntervalId.majorSeventh, t),
      );

      // 增量阶段不应写 stats.json（只在 finishSession 落盘）。
      expect(File('${dir.path}/stats.json').existsSync(), isFalse);
      // 但 JSONL 流水应已存在并可读回 2 条。
      final appender = JsonlAppender(dir: dir);
      expect(appender.readAll().lines.length, 2);
    });

    test('按月分片：不同月份落到不同文件', () async {
      await repo.recordAttempt(
        _attempt('s', IntervalId.minorSecond, IntervalId.minorSecond,
            DateTime.utc(2026, 1, 15)),
      );
      await repo.recordAttempt(
        _attempt('s', IntervalId.majorSeventh, IntervalId.majorSeventh,
            DateTime.utc(2026, 2, 15)),
      );
      await repo.recordAttempt(
        _attempt('s', IntervalId.minorThird, IntervalId.minorThird,
            DateTime.utc(2026, 2, 20)),
      );

      final jan = File('${dir.path}/attempts_2026-01.jsonl');
      final feb = File('${dir.path}/attempts_2026-02.jsonl');
      expect(jan.existsSync(), isTrue);
      expect(feb.existsSync(), isTrue);
      final appender = JsonlAppender(dir: dir);
      expect(appender.readAll().lines.length, 3);
    });

    test('stats.json 可重建：损坏后由 JSONL 全量重算，与增量结果完全一致', () async {
      final t = DateTime.utc(2026, 3, 5);
      await repo.recordAttempt(
        _attempt('s1', IntervalId.minorSecond, IntervalId.minorSecond, t,
            uncertain: false),
      );
      await repo.recordAttempt(
        _attempt('s1', IntervalId.majorSeventh, IntervalId.minorSecond, t),
      );
      await repo.recordAttempt(
        _attempt('s1', IntervalId.minorThird, IntervalId.minorThird,
            t.add(const Duration(hours: 1)), uncertain: true),
      );
      await repo.finishSession(_session('s1', t));

      // 增量快照（来自落盘的 stats.json）。
      final incremental = await repo.loadStats();

      // 破坏 stats.json，触发从 JSONL 流水的全量重建（真实重建路径）。
      File('${dir.path}/stats.json').writeAsStringSync('GARBAGE_NOT_JSON');
      final rebuilt = await repo.loadStats();

      // 两个真相必须完全一致（无第二个真相）：重建结果与增量快照逐字段相等。
      expect(rebuilt, incremental);
      expect(rebuilt.totalQuestions, 3);
    });

    test('RecoveryReport：损坏 JSONL 行被记录但有效 attempts 保留', () async {
      final t = DateTime.utc(2026, 4, 1);
      await repo.recordAttempt(
        _attempt('s1', IntervalId.minorSecond, IntervalId.minorSecond, t),
      );
      await repo.recordAttempt(
        _attempt('s1', IntervalId.majorSeventh, IntervalId.majorSeventh, t),
      );

      // 在 JSONL 末尾插入一行垃圾，模拟损坏行。
      final file = File('${dir.path}/attempts_2026-04.jsonl');
      expect(file.existsSync(), isTrue);
      await file.writeAsString('GARBAGE_LINE_NOT_JSON\n', mode: FileMode.append);

      // loadStats 检测到损坏行 → 从流水重建并产出恢复报告。
      await repo.loadStats();
      final report = await repo.takeRecoveryReport();

      expect(report, isNotNull);
      expect(report!.hasRecovery, isTrue);
      expect(report.skippedAttemptLines, 1);
      expect(report.recoveredAttempts, 2);
      expect(report.statsRebuilt, isTrue);

      // 有效 attempts 仍可被读取（未丢失）。
      final early = DateTime.utc(2026, 3, 1);
      final late = DateTime.utc(2026, 5, 1);
      final valid = await repo.attemptsInRange(early, late);
      expect(valid.length, 2);
    });

    test('clearAll 幂等：连续两次不报错', () async {
      final t = DateTime.utc(2026, 5, 1);
      await repo.recordAttempt(
        _attempt('s1', IntervalId.minorSecond, IntervalId.minorSecond, t),
      );
      await repo.finishSession(_session('s1', t));

      await repo.clearAll();
      await repo.clearAll(); // 第二次应为幂等，不抛。
      final snapshot = await repo.loadStats();
      expect(snapshot.isEmpty, isTrue);
    });

    test('rebuildFromAttempts 处理 10000 条耗时 < 2s（性能契约）', () {
      final base = DateTime.utc(2026, 6, 1);
      final attempts = <TrainingAttempt>[];
      for (var i = 0; i < 10000; i++) {
        attempts.add(
          _attempt(
            's',
            IntervalCatalog.trainableIds.toList()[i % 13],
            IntervalCatalog.trainableIds.toList()[(i + 1) % 13],
            base.add(Duration(seconds: i)),
          ),
        );
      }
      final sw = Stopwatch()..start();
      final snapshot = StatsRebuilder.rebuild(attempts, const <TrainingSession>[]);
      sw.stop();
      expect(snapshot.totalQuestions, 10000);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    // ---- T23 验收 ⑥：中途退出落盘不污染统计 ----

    test('abortSession 只写流水，不进统计（正确率与组数都不受影响）', () async {
      final t = DateTime.utc(2026, 7, 1);
      // 先正常打完一组：2 题全对。
      await repo.recordAttempt(
        _attempt('s1', IntervalId.minorSecond, IntervalId.minorSecond, t),
      );
      await repo.recordAttempt(
        _attempt('s1', IntervalId.majorSeventh, IntervalId.majorSeventh, t),
      );
      await repo.finishSession(_session('s1', t));
      final before = await repo.loadStats();

      // 再中途退出一组（未结算）。
      await repo.abortSession(
        _session('s2', t.add(const Duration(hours: 1)), finished: false),
      );
      final after = await repo.loadStats();

      expect(after.totalSessions, before.totalSessions);
      expect(after.totalQuestions, before.totalQuestions);
      // 日历（每日汇总）同样不该多出一组。
      expect(after.daily.length, before.daily.length);
    });

    test('abortSession 强制打上 aborted 标记并落到会话流水', () async {
      final t = DateTime.utc(2026, 7, 2);
      // 传入未标记的会话，实现应强制标记。
      await repo.abortSession(_session('s3', t, finished: false));

      final file = File('${dir.path}/sessions_2026-07.jsonl');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('"aborted":true'));
    });

    test('recentSessions 不返回 aborted 记录（不挤占章节推进窗口）', () async {
      final t = DateTime.utc(2026, 7, 3);
      await repo.finishSession(_session('done', t));
      await repo.abortSession(
        _session('quit', t.add(const Duration(hours: 2)), finished: false),
      );

      final recent = await repo.recentSessions(10);
      expect(
        recent.map((s) => s.sessionId).toList(),
        <String>['done'],
      );
    });

    test('从流水全量重建时同样跳过 aborted 会话', () {
      // 直接打在纯函数上：无论增量累计还是全量重建，aborted 都不进统计，
      // 两条路径的结果因此始终一致（T16 验收 2 的不变式在 T23 后仍成立）。
      final t = DateTime.utc(2026, 7, 4);
      final rebuilt = StatsRebuilder.rebuild(
        <TrainingAttempt>[
          _attempt('s1', IntervalId.minorSecond, IntervalId.minorSecond, t),
        ],
        <TrainingSession>[
          _session('s1', t),
          // 中途退出：既没有 finishedAt，也带 aborted 标记。
          _session('s2', t.add(const Duration(hours: 1)), finished: false)
              .copyWith(aborted: true),
        ],
      );

      expect(rebuilt.totalSessions, 1);
      expect(rebuilt.totalQuestions, 1);
    });
  });

  group('SettingsRepository（T16 设置往返）', () {
    late Directory dir;
    late SettingsRepositoryImpl repo;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('settings_test_');
      repo = SettingsRepositoryImpl(dataDir: dir);
    });

    tearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('保存后读回与领域设置完全一致（含 ThemePreference，非 flutter ThemeMode）',
        () async {
      final settings = AppSettings.defaults.copyWith(
        themeMode: ThemePreference.dark,
        celebrationLevel: CelebrationLevel.rich,
        motionPreference: MotionPreference.reduced,
        volume: 0.5,
        visualizerStyle: VisualizerStyle.spectrum,
      );
      await repo.save(settings);
      final loaded = await repo.load();
      expect(loaded, settings);
      expect(loaded.themeMode, ThemePreference.dark);
      expect(loaded.celebrationLevel, CelebrationLevel.rich);
    });

    test('文件缺失时降级到默认值', () async {
      final loaded = await repo.load();
      expect(loaded, AppSettings.defaults);
    });
  });
}
