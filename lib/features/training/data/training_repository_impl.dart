import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/storage/json_file_store.dart';
import 'package:interval_ear/core/storage/jsonl_appender.dart';
import 'package:interval_ear/core/utils/app_logger.dart';
import 'package:interval_ear/features/training/data/attempt_dto.dart';
import 'package:interval_ear/features/training/data/session_dto.dart';
import 'package:interval_ear/features/training/data/stats_dto.dart';
import 'package:interval_ear/features/training/data/stats_store.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/repositories/recovery_report.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 训练数据仓储实现（T16）。
///
/// 组合 `JsonFileStore`（stats.json 原子写）+ `JsonlAppender`（按月分片流水）+
/// `StatsStore`（内存增量）。JSONL 是唯一真相源，`stats.json` 是缓存，可重建。
class TrainingRepositoryImpl implements TrainingRepository {
  /// 创建实现（[dataDir] 为训练数据目录）。
  TrainingRepositoryImpl({required Directory dataDir})
      : _fileStore = JsonFileStore(dir: dataDir),
        _attempts = JsonlAppender(dir: dataDir),
        _sessions = JsonlAppender(dir: dataDir),
        _stats = StatsStore(fileStore: JsonFileStore(dir: dataDir));

  final JsonFileStore _fileStore;
  final JsonlAppender _attempts;
  final JsonlAppender _sessions;
  final StatsStore _stats;

  final StreamController<StatsSnapshot> _statsController =
      StreamController<StatsSnapshot>.broadcast();

  RecoveryReport? _pendingRecovery;

  static const String _attemptsPrefix = 'attempts';
  static const String _sessionsPrefix = 'sessions';

  static String _ym(DateTime dt) {
    final d = dt.toUtc();
    final mm = d.month.toString().padLeft(2, '0');
    return '${d.year}-$mm';
  }

  static String _attemptShard(DateTime dt) =>
      '${_attemptsPrefix}_${_ym(dt)}.jsonl';

  static String _sessionShard(DateTime dt) =>
      '${_sessionsPrefix}_${_ym(dt)}.jsonl';

  @override
  Stream<StatsSnapshot> get statsChanges => _statsController.stream;

  @override
  Future<void> startSession(TrainingSession session) async {
    await _sessions.append(_sessionShard(session.startedAt),
        SessionDto(session).toJson());
  }

  @override
  Future<void> recordAttempt(TrainingAttempt attempt) async {
    // 流水追加 + 内存增量，不重写 stats.json（T16 验收 3）。
    await _attempts.append(
      _attemptShard(attempt.createdAt),
      AttemptDto(attempt).toJson(),
    );
    _stats.applyAttempt(attempt);
    _notify();
  }

  @override
  Future<void> finishSession(TrainingSession session) async {
    await _sessions.append(
      _sessionShard(session.startedAt),
      SessionDto(session).toJson(),
    );
    _stats.applySession(session);
    await _persistStats();
    _notify();
  }

  @override
  Future<StatsSnapshot> loadStats() async {
    final statsFile =
        File('${_fileStore.dir.path}/${AppConfig.statsFileName}');
    final bool statsCorrupt = await _isStatsCorrupt(statsFile);
    if (statsCorrupt) {
      await _fileStore.backupCorrupt(AppConfig.statsFileName);
    }

    await _stats.init();

    final attemptResult = _attempts.readAll(prefix: _attemptsPrefix);
    final sessionResult = _sessions.readAll(prefix: _sessionsPrefix);

    if (statsCorrupt || attemptResult.hasCorruption) {
      // 从流水重建 stats.json（T16 验收 1 / 2）。
      final attempts = attemptResult.lines
          .map((m) => AttemptDto.fromJson(m).attempt)
          .toList(growable: false);
      final sessions = sessionResult.lines
          .map((m) => SessionDto.fromJson(m).session)
          .toList(growable: false);
      await _stats.rebuildFromAttempts(attempts, sessions);
      await _persistStats();
      _pendingRecovery = RecoveryReport(
        skippedAttemptLines: attemptResult.skippedLines,
        statsRebuilt: true,
        recoveredAttempts: attempts.length,
        corruptFiles: <String>[
          ...attemptResult.corruptFiles,
          if (statsCorrupt) statsFile.path,
        ],
      );
      AppLogger.info(
        'stats rebuilt from ${attempts.length} attempts '
        '(${attemptResult.skippedLines} lines skipped)',
        tag: 'TrainingRepository',
      );
    }

    _notify();
    return _stats.snapshot;
  }

  @override
  Future<List<TrainingSession>> recentSessions(int limit) async {
    final result = _sessions.readAll(prefix: _sessionsPrefix);
    final sessions = result.lines
        .map((m) => SessionDto.fromJson(m).session)
        .toList(growable: false);
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (limit > 0 && sessions.length > limit) {
      sessions.removeRange(limit, sessions.length);
    }
    return sessions;
  }

  @override
  Future<List<TrainingAttempt>> attemptsInRange(
    DateTime from,
    DateTime to,
  ) async {
    final result = _attempts.readAll(prefix: _attemptsPrefix);
    final attempts = result.lines
        .map((m) => AttemptDto.fromJson(m).attempt)
        .where((a) => !a.createdAt.isBefore(from) && !a.createdAt.isAfter(to))
        .toList(growable: false);
    return attempts;
  }

  @override
  Future<RecoveryReport?> takeRecoveryReport() async {
    final report = _pendingRecovery;
    _pendingRecovery = null;
    return report;
  }

  @override
  Future<void> clearAll() async {
    await _attempts.deleteAll();
    await _sessions.deleteAll();
    await _fileStore.delete(AppConfig.statsFileName);
    _stats.reset();
    _pendingRecovery = null;
    _notify();
  }

  @override
  Future<String> exportJson() async {
    final attemptResult = _attempts.readAll(prefix: _attemptsPrefix);
    final sessionResult = _sessions.readAll(prefix: _sessionsPrefix);
    final payload = <String, dynamic>{
      'schema': 'interval_ear.export',
      'schemaVersion': 1,
      'sessions': sessionResult.lines
          .map((m) => SessionDto.fromJson(m).toJson())
          .toList(),
      'attempts': attemptResult.lines
          .map((m) => AttemptDto.fromJson(m).toJson())
          .toList(),
      'stats': StatsDto(_stats.snapshot).toJson(),
    };
    return jsonEncode(payload);
  }

  @override
  Future<void> flush() async {
    await _persistStats();
  }

  /// 释放统计流（应用退出时调用）。
  Future<void> dispose() async {
    if (!_statsController.isClosed) {
      await _statsController.close();
    }
  }

  Future<bool> _isStatsCorrupt(File statsFile) async {
    if (!await statsFile.exists()) {
      return false;
    }
    try {
      final content = await statsFile.readAsString();
      if (content.trim().isEmpty) {
        return true;
      }
      jsonDecode(content);
      return false;
    } on Object {
      return true;
    }
  }

  Future<void> _persistStats() async {
    await _fileStore.writeAtomic(
      AppConfig.statsFileName,
      StatsDto(_stats.snapshot).toJson(),
    );
  }

  void _notify() {
    if (!_statsController.isClosed) {
      _statsController.add(_stats.snapshot);
    }
  }
}
