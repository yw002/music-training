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
    await _sessions.append(
        _sessionShard(session.startedAt), SessionDto(session).toJson());
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
  Future<void> abortSession(TrainingSession session) async {
    // 只追加流水，**不** applySession：aborted 会话不进统计（T23 验收 ⑥）。
    // 仍然落一次 stats.json，保证退出前内存里的作答增量不丢。
    final TrainingSession aborted =
        session.aborted ? session : session.copyWith(aborted: true);
    await _sessions.append(
      _sessionShard(aborted.startedAt),
      SessionDto(aborted).toJson(),
    );
    await _persistStats();
    _notify();
  }

  @override
  Future<StatsSnapshot> loadStats() async {
    final statsFile = File('${_fileStore.dir.path}/${AppConfig.statsFileName}');
    final bool statsExists = await statsFile.exists();
    final bool statsCorrupt = await _isStatsCorrupt(statsFile);
    if (statsCorrupt) {
      await _fileStore.backupCorrupt(AppConfig.statsFileName);
    }

    await _stats.init();

    final attemptResult = _attempts.readAll(prefix: _attemptsPrefix);
    final sessionResult = _sessions.readAll(prefix: _sessionsPrefix);

    final attempts = attemptResult.lines
        .map((m) => AttemptDto.fromJson(m).attempt)
        .toList(growable: false);
    final sessions = sessionResult.lines
        .map((m) => SessionDto.fromJson(m).session)
        .toList(growable: false);
    final rebuilt = StatsSnapshot.rebuildFromAttempts(attempts, sessions);
    final bool cacheStale = rebuilt != _stats.snapshot;
    final bool journalHasData = attempts.isNotEmpty || sessions.isNotEmpty;
    final bool needsRebuild = statsCorrupt ||
        attemptResult.hasCorruption ||
        sessionResult.hasCorruption ||
        cacheStale ||
        (!statsExists && journalHasData);

    if (needsRebuild) {
      // JSONL 是唯一真相源；即使 stats.json 能解析，落后流水也必须重建。
      await _stats.rebuildFromAttempts(attempts, sessions);
      await _persistStats();
      _pendingRecovery = RecoveryReport(
        skippedAttemptLines: attemptResult.skippedLines,
        statsRebuilt: true,
        recoveredAttempts: attempts.length,
        corruptFiles: <String>[
          ...attemptResult.corruptFiles,
          ...sessionResult.corruptFiles,
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
    final latestById = <String, TrainingSession>{};
    for (final line in result.lines) {
      final session = SessionDto.fromJson(line).session;
      final previous = latestById[session.sessionId];
      if (previous == null ||
          (session.finishedAt ?? session.startedAt)
              .isAfter(previous.finishedAt ?? previous.startedAt)) {
        latestById[session.sessionId] = session;
      }
    }
    final sessions = latestById.values
        // T23：中途退出的记录只是排查用的面包屑，不是「一组训练」。
        // 若把它算进最近 N 条，会挤掉真正已结算的会话，让章节推进判定
        // （SessionRunner.shouldAdvanceChapter 取最近若干组）被无谓拖慢。
        .where((s) => !s.aborted && s.isFinished())
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
  Future<void> importJson(String json) async {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(json) as Map<String, dynamic>;
    } on Object {
      throw const FormatException('导出文件格式不正确');
    }
    if (payload['schema'] != 'interval_ear.export' ||
        payload['schemaVersion'] != 1 ||
        payload['sessions'] is! List ||
        payload['attempts'] is! List) {
      throw const FormatException('导出文件格式不正确');
    }
    try {
      final rawSessions = payload['sessions']! as List<dynamic>;
      final rawAttempts = payload['attempts']! as List<dynamic>;
      if (rawSessions.any((e) => e is! Map<String, dynamic>) ||
          rawAttempts.any((e) => e is! Map<String, dynamic>)) {
        throw const FormatException('导出文件格式不正确');
      }
      final sessionMaps = rawSessions.cast<Map<String, dynamic>>();
      final attemptMaps = rawAttempts.cast<Map<String, dynamic>>();
      if (sessionMaps.any((m) =>
              m['type'] != SessionDto.type ||
              m['sessionId'] is! String ||
              m['startedAt'] is! String ||
              m['configSnapshot'] is! Map) ||
          attemptMaps.any((m) =>
              m['type'] != AttemptDto.type ||
              m['attemptId'] is! String ||
              m['sessionId'] is! String ||
              m['createdAt'] is! String ||
              m['correctInterval'] is! String)) {
        throw const FormatException('导出文件格式不正确');
      }
      final sessions = sessionMaps
          .map((e) => SessionDto.fromJson(e).session)
          .toList(growable: false);
      final attempts = attemptMaps
          .map((e) => AttemptDto.fromJson(e).attempt)
          .toList(growable: false);
      await _replaceTrainingData(sessions, attempts);
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('导出文件格式不正确');
    }
  }

  /// 先在同盘临时目录生成完整数据，再用备份回滚的文件级交换提交。
  Future<void> _replaceTrainingData(
    List<TrainingSession> sessions,
    List<TrainingAttempt> attempts,
  ) async {
    final Directory dataDir = _fileStore.dir;
    final String nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final Directory staging = Directory('${dataDir.path}.import-$nonce');
    final Directory backup = Directory('${dataDir.path}.backup-$nonce');
    final staged = TrainingRepositoryImpl(dataDir: staging);
    bool backupCanBeDeleted = false;
    try {
      await staging.create(recursive: true);
      for (final TrainingSession session in sessions) {
        await staged._sessions.append(
          _sessionShard(session.startedAt),
          SessionDto(session).toJson(),
        );
      }
      for (final TrainingAttempt attempt in attempts) {
        await staged._attempts.append(
          _attemptShard(attempt.createdAt),
          AttemptDto(attempt).toJson(),
        );
      }
      await staged._stats.rebuildFromAttempts(attempts, sessions);
      await staged._persistStats();
      await staged.dispose();

      await backup.create(recursive: true);
      final movedImports = <File>[];
      try {
        for (final File file in await _trainingFiles(dataDir)) {
          await file.rename('${backup.path}/${_basename(file.path)}');
        }
        for (final File file in await _trainingFiles(staging)) {
          movedImports.add(
            await file.rename('${dataDir.path}/${_basename(file.path)}'),
          );
        }
      } on Object {
        for (final File file in movedImports) {
          if (await file.exists()) await file.delete();
        }
        for (final File file in await _trainingFiles(backup)) {
          await file.rename('${dataDir.path}/${_basename(file.path)}');
        }
        backupCanBeDeleted = true;
        rethrow;
      }

      await _stats.rebuildFromAttempts(attempts, sessions);
      _pendingRecovery = null;
      _notify();
      backupCanBeDeleted = true;
    } finally {
      await staged.dispose();
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      if (backupCanBeDeleted && await backup.exists()) {
        await backup.delete(recursive: true);
      }
    }
  }

  static Future<List<File>> _trainingFiles(Directory dir) async {
    if (!await dir.exists()) return <File>[];
    return dir.listSync().whereType<File>().where((file) {
      final name = _basename(file.path);
      return name == AppConfig.statsFileName ||
          name.startsWith('${_attemptsPrefix}_') ||
          name.startsWith('${_sessionsPrefix}_');
    }).toList(growable: false);
  }

  static String _basename(String path) =>
      path.replaceAll('\\', '/').split('/').last;

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
