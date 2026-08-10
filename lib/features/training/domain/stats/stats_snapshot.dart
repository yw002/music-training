import 'package:equatable/equatable.dart';
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/schema_version.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/stats/confusion_matrix.dart';
import 'package:interval_ear/features/training/domain/stats/daily_summary.dart';
import 'package:interval_ear/features/training/domain/stats/dimension_statistics.dart';
import 'package:interval_ear/features/training/domain/stats/interval_statistics.dart';
import 'package:interval_ear/features/training/domain/stats/pair_statistics.dart';
import 'package:interval_ear/features/training/domain/stats/recent_outcome.dart';

/// 所有训练统计的根聚合（架构 §3.2）。
///
/// 它是 `stats.json` 落盘时的唯一顶层结构。**一切统计都能从
/// `attempts.jsonl`（外加 `sessions.jsonl`）完全重算**——这是 StatRepo 的
/// 重建契约（`rebuildFromAttempts`）。因此本对象只是这些流水的一个「视图缓存」，
/// 不持有任何算不出来的状态。
///
/// 注意：内部持有的 [confusionMatrix] 是**可变**对象（热路径），对外通过
/// [ConfusionMatrix.copy] 暴露副本，调用方不应改动拿到的引用。
class StatsSnapshot extends Equatable {
  /// 创建快照。建议使用 [empty] / [rebuildFromAttempts]。
  StatsSnapshot({
    Map<IntervalId, IntervalStatistics>? intervals,
    ConfusionMatrix? confusionMatrix,
    this.dimensions = DimensionStatistics.empty,
    Map<String, DailySummary>? daily,
    Map<String, PairStatistics>? pairs,
    List<RecentOutcome>? recentOutcomes,
    this.totalSessions = 0,
    this.totalQuestions = 0,
    this.lastTrainedAt,
    this.schemaVersion = kDomainSchemaVersion,
  }) : intervals = Map<IntervalId, IntervalStatistics>.unmodifiable(
         intervals ?? const <IntervalId, IntervalStatistics>{},
       ),
       confusionMatrix = confusionMatrix ?? ConfusionMatrix.empty(),
       daily = Map<String, DailySummary>.unmodifiable(
         daily ?? const <String, DailySummary>{},
       ),
       pairs = Map<String, PairStatistics>.unmodifiable(
         pairs ?? const <String, PairStatistics>{},
       ),
       recentOutcomes = List<RecentOutcome>.unmodifiable(
         recentOutcomes ?? const <RecentOutcome>[],
       );

  /// 全空快照（新用户零历史）。
  factory StatsSnapshot.empty() => StatsSnapshot();

  /// 各音程累计统计。
  final Map<IntervalId, IntervalStatistics> intervals;

  /// 混淆矩阵（可变，落盘前会 [ConfusionMatrix.copy] 出去）。
  final ConfusionMatrix confusionMatrix;

  /// 跨音程的维度统计。
  final DimensionStatistics dimensions;

  /// 按 `yyyy-MM-dd` 索引的单日汇总。
  final Map<String, DailySummary> daily;

  /// 按 `IntervalPair.key()` 索引的二选一音程对统计。
  final Map<String, PairStatistics> pairs;

  /// 最近 [kRecentOutcomeCapacity] 次作答的精简记录，用于结算页瞬时反馈。
  final List<RecentOutcome> recentOutcomes;

  /// 累计完成会话数。
  final int totalSessions;

  /// 累计作答题数（含「不确定」）。
  final int totalQuestions;

  /// 最近一次训练时刻。
  final DateTime? lastTrainedAt;

  /// 落盘 schema 版本。
  final int schemaVersion;

  /// 是否零历史。
  bool get isEmpty =>
      intervals.isEmpty && totalQuestions == 0 && confusionMatrix.isEmpty;

  /// 取某音程的统计；从未练过时返回一个合法但全零的 [IntervalStatistics]
  /// （不返回 null）。
  IntervalStatistics intervalOf(IntervalId id) =>
      intervals[id] ?? IntervalStatistics.empty(id);

  /// 取某日的汇总；无记录返回当天空汇总（日期键取自 [DateKeys]）。
  DailySummary dayOf(String dateKey) =>
      daily[dateKey] ?? DailySummary(dateKey: dateKey);

  /// 取某音程对的统计；无记录返回空统计。
  PairStatistics pairOf(IntervalPair pair) =>
      pairs[pair.key()] ?? PairStatistics.empty(pair);

  /// 全局正确率（展示口径，含「不确定」）。
  ///
  /// `T01` 已落地的结算页用 [TrainingSession.accuracy]，这里是对整段历史的汇总，
  /// 供「我的」页长期趋势使用。
  double overallAccuracy() {
    var correct = 0;
    var total = 0;
    for (final stat in intervals.values) {
      correct += stat.correctCount;
      total += stat.totalCount;
    }
    if (total == 0) {
      return 0;
    }
    return correct / total;
  }

  /// 返回最近 [days] 天的单日汇总，**缺失的日期用空汇总补全**。
  ///
  /// 趋势折线图要的是「均匀采样的时间序列」，缺哪天补哪天，否则 0 题的休息日
  /// 会凭空消失、曲线被拉成连续训练的样子。
  List<DailySummary> recentDays(int days, DateTime now) {
    if (days <= 0) {
      return const <DailySummary>[];
    }
    final result = <DailySummary>[];
    final base = now.toLocal();
    for (var i = days - 1; i >= 0; i--) {
      final day = base.subtract(Duration(days: i));
      final key = DateKeys.of(day);
      result.add(daily[key] ?? DailySummary(dateKey: key));
    }
    return List<DailySummary>.unmodifiable(result);
  }

  /// 用一条新作答增量更新（不可变返回新快照）。
  ///
  /// 注意：混淆矩阵内部可变，这里直接 `absorb` 到 [confusionMatrix] 上，因为
  /// 新快照持有的是**同一个矩阵实例**——这正是 @immutable 所禁止的「共享可变状态」。
  /// 但本方法是**同步、隔离**地在一个快照上推进，且 [confusionMatrix] 不对外
  /// 暴露可变方法（外部只能拿到 [ConfusionMatrix.copy] 副本），因此不构成并发隐患。
  StatsSnapshot withAttempt(TrainingAttempt attempt) {
    var stat = intervalOf(attempt.correctInterval);
    stat = stat.withAttempt(attempt);
    final nextIntervals = Map<IntervalId, IntervalStatistics>.of(intervals);
    nextIntervals[attempt.correctInterval] = stat;

    final nextDimensions = dimensions.withAttempt(attempt);

    final dateKey = DateKeys.of(attempt.createdAt);
    final nextDaily = Map<String, DailySummary>.of(daily);
    nextDaily[dateKey] = (nextDaily[dateKey] ?? DailySummary(dateKey: dateKey))
        .withAttempt(attempt);

    final nextPairs = Map<String, PairStatistics>.of(pairs);
    final pairKey = attempt.focusPair;
    if (pairKey != null) {
      final pair = IntervalPair.tryFromKey(pairKey);
      if (pair != null) {
        final current = pairs[pairKey] ?? PairStatistics.empty(pair);
        nextPairs[pairKey] = current.withAttempt(attempt);
      }
    }

    final nextRecent = <RecentOutcome>[
      ...recentOutcomes,
      RecentOutcome.fromAttempt(attempt),
    ];
    if (nextRecent.length > kRecentOutcomeCapacity) {
      nextRecent.removeRange(0, nextRecent.length - kRecentOutcomeCapacity);
    }

    final matrix = confusionMatrix.copy();
    matrix.absorb(attempt);

    return StatsSnapshot(
      intervals: nextIntervals,
      confusionMatrix: matrix,
      dimensions: nextDimensions,
      daily: nextDaily,
      pairs: nextPairs,
      recentOutcomes: nextRecent,
      totalSessions: totalSessions,
      totalQuestions: totalQuestions + 1,
      lastTrainedAt: _laterOf(lastTrainedAt, attempt.createdAt),
      schemaVersion: schemaVersion,
    );
  }

  /// 用一次完成的会话增量更新（不可变返回新快照）。
  StatsSnapshot withSession(TrainingSession session) {
    // 中途退出（T23 验收 ⑥）与未结算的会话一律不进统计：既不加 totalSessions，
    // 也不写 daily / lastTrainedAt，保证「打了一半就退出」不污染正确率与日历。
    if (session.aborted || !session.isFinished()) {
      return this;
    }
    final nextDaily = Map<String, DailySummary>.of(daily);
    final dateKey = DateKeys.of(session.finishedAt!);
    nextDaily[dateKey] = (nextDaily[dateKey] ?? DailySummary(dateKey: dateKey))
        .withSession(session);

    return StatsSnapshot(
      intervals: intervals,
      confusionMatrix: confusionMatrix,
      dimensions: dimensions,
      daily: nextDaily,
      pairs: pairs,
      recentOutcomes: recentOutcomes,
      totalSessions: totalSessions + 1,
      totalQuestions: totalQuestions,
      lastTrainedAt: _laterOf(lastTrainedAt, session.finishedAt!),
      schemaVersion: schemaVersion,
    );
  }

  /// 从全量流水重算（StatRepo 的重建契约）。
  ///
  /// 这里故意走「逐个 [withAttempt]」而非手写一个独立的 fold：保证增量更新与
  /// 全量重建**结果完全一致**，不会出现「重建出来的数据和运行中累计的不一样」。
  /// 对于成千上万条流水，性能完全够用（瓶颈在 I/O 而非这层纯内存聚合）。
  factory StatsSnapshot.rebuildFromAttempts(
    List<TrainingAttempt> attempts,
    List<TrainingSession> sessions,
  ) {
    var snapshot = StatsSnapshot.empty();
    for (final attempt in attempts) {
      snapshot = snapshot.withAttempt(attempt);
    }
    for (final session in sessions) {
      snapshot = snapshot.withSession(session);
    }
    return snapshot;
  }

  static DateTime? _laterOf(DateTime? a, DateTime b) =>
      a == null || b.isAfter(a) ? b : a;

  /// 序列化。各子结构用自己的短键，顶层除 `schemaVersion` 外都带 `s` 前缀避免
  /// 与子结构的 `daily` 字段重名。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'intervals': <String, dynamic>{
      for (final entry in intervals.entries)
        entry.key.storageId: entry.value.toJson(),
    },
    'confusion': confusionMatrix.toJson(),
    'dimensions': dimensions.toJson(),
    'daily': <String, dynamic>{
      for (final entry in daily.entries) entry.key: entry.value.toJson(),
    },
    'pairs': <String, dynamic>{
      for (final entry in pairs.entries) entry.key: entry.value.toJson(),
    },
    'recent': <Map<String, dynamic>>[
      for (final outcome in recentOutcomes) outcome.toJson(),
    ],
    'totalSessions': totalSessions,
    'totalQuestions': totalQuestions,
    if (lastTrainedAt != null)
      'lastTrainedAt': lastTrainedAt!.toUtc().toIso8601String(),
  };

  /// 反序列化。任一子结构非法则该字段退回空，不整体抛。
  factory StatsSnapshot.fromJson(Map<String, dynamic> json) {
    final intervals = <IntervalId, IntervalStatistics>{};
    final rawIntervals = json['intervals'];
    if (rawIntervals is Map) {
      for (final entry in rawIntervals.entries) {
        final id = IntervalId.tryFromStorageId(entry.key);
        final value = entry.value;
        if (id != null && value is Map<String, dynamic>) {
          intervals[id] = IntervalStatistics.fromJson(value);
        }
      }
    }

    final daily = <String, DailySummary>{};
    final rawDaily = json['daily'];
    if (rawDaily is Map) {
      for (final entry in rawDaily.entries) {
        final value = entry.value;
        if (entry.key is String && value is Map<String, dynamic>) {
          daily[entry.key as String] = DailySummary.fromJson(value);
        }
      }
    }

    final pairs = <String, PairStatistics>{};
    final rawPairs = json['pairs'];
    if (rawPairs is Map) {
      for (final entry in rawPairs.entries) {
        final value = entry.value;
        if (entry.key is String && value is Map<String, dynamic>) {
          pairs[entry.key as String] = PairStatistics.fromJson(value);
        }
      }
    }

    final recent = <RecentOutcome>[];
    final rawRecent = json['recent'];
    if (rawRecent is List) {
      for (final item in rawRecent) {
        if (item is Map<String, dynamic>) {
          recent.add(RecentOutcome.fromJson(item));
        }
      }
    }

    return StatsSnapshot(
      intervals: intervals,
      confusionMatrix: ConfusionMatrix.fromJson(json['confusion']),
      dimensions: json['dimensions'] is Map<String, dynamic>
          ? DimensionStatistics.fromJson(
              json['dimensions'] as Map<String, dynamic>,
            )
          : DimensionStatistics.empty,
      daily: daily,
      pairs: pairs,
      recentOutcomes: recent,
      totalSessions: _readInt(json['totalSessions']),
      totalQuestions: _readInt(json['totalQuestions']),
      lastTrainedAt: _readNullableTime(json['lastTrainedAt']),
      schemaVersion: readSchemaVersion(json),
    );
  }

  static int _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return 0;
  }

  static DateTime? _readNullableTime(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc();
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[
    intervals,
    confusionMatrix,
    dimensions,
    daily,
    pairs,
    recentOutcomes,
    totalSessions,
    totalQuestions,
    lastTrainedAt?.toUtc(),
    schemaVersion,
  ];

  @override
  String toString() =>
      'StatsSnapshot('
      '${intervals.length} intervals, ${daily.length} days, '
      '${pairs.length} pairs, $totalQuestions attempts)';
}
