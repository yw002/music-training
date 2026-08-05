import 'package:equatable/equatable.dart';
import 'package:interval_ear/core/utils/math_utils.dart';
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/stats/accuracy_bucket.dart';

/// 单个音程的累计统计（架构 §3.2）。
///
/// **与类图的两点偏离（有意为之）**：
/// 1. 类图里的 `masteryScore` 字段被移除。掌握度是 `MasteryCalculator` 的**纯函数
///    输出**，把它当字段存下来就会出现「字段过期但没人重算」的第二真相；而且
///    `IntervalStatistics` 反过来 import `MasteryCalculator` 会形成循环依赖。
///    调用方一律写 `MasteryCalculator.compute(stats)`。
/// 2. 类图里的 `mostConfusedWith` 被移除。它需要混淆矩阵才能算，而矩阵挂在
///    `StatsSnapshot` 上，放这里会让本类无法独立构造。改由
///    `ConfusionAnalyzer.mostConfusedWith(id, snapshot)` 提供。
///
/// **新增字段** [recentOutcomes]：§5.1 的公式需要「最近 R 次是否答对」，类图漏了，
/// 这里补上。只保留最近 [kRecentWindow] 条，落盘体积恒定。
class IntervalStatistics extends Equatable {
  /// 创建一条音程统计。
  const IntervalStatistics({
    required this.interval,
    this.totalCount = 0,
    this.correctCount = 0,
    this.firstPlayCorrectCount = 0,
    this.replayCount = 0,
    this.uncertainCount = 0,
    this.totalResponseMs = 0,
    this.lastSeenAt,
    this.byDirection = const <PlaybackDirection, AccuracyBucket>{},
    this.byRootMode = const <RootMode, AccuracyBucket>{},
    this.byTimbre = const <Timbre, AccuracyBucket>{},
    this.recentOutcomes = const <bool>[],
  });

  /// 该音程的空统计。
  factory IntervalStatistics.empty(IntervalId interval) =>
      IntervalStatistics(interval: interval);

  /// 音程标识。
  final IntervalId interval;

  /// 总作答数（含「不确定」）。
  final int totalCount;

  /// 答对数。
  final int correctCount;

  /// 首播即答对数。
  final int firstPlayCorrectCount;

  /// 累计重播次数。
  final int replayCount;

  /// 「不确定」次数。
  final int uncertainCount;

  /// 累计响应耗时（毫秒）。
  final int totalResponseMs;

  /// 最近一次出现的时刻。
  final DateTime? lastSeenAt;

  /// 按播放方向拆分。
  final Map<PlaybackDirection, AccuracyBucket> byDirection;

  /// 按根音策略拆分。
  final Map<RootMode, AccuracyBucket> byRootMode;

  /// 按音色拆分。
  final Map<Timbre, AccuracyBucket> byTimbre;

  /// 最近 [kRecentWindow] 次**有效**作答是否答对（「不确定」不入列）。
  ///
  /// 末尾是最新一条。用 `List<bool>` 而不是 `List<RecentOutcome>`：掌握度只关心
  /// 对错，存完整对象会让 stats.json 里每个音程多出十几倍体积。
  final List<bool> recentOutcomes;

  /// 有效作答数 `n`（剔除「不确定」），即 §5.1 公式的分母。
  int get effectiveCount {
    final n = totalCount - uncertainCount;
    return n < 0 ? 0 : n;
  }

  /// 原始正确率 `[0, 1]`；无有效样本时为 0（不产生 NaN）。
  double get rawAccuracy => MathUtils.safeDivide(correctCount, effectiveCount);

  /// 首播正确率 `[0, 1]`。
  double get firstPlayAccuracy =>
      MathUtils.safeDivide(firstPlayCorrectCount, effectiveCount);

  /// 近期正确率 `[0, 1]`；[recentOutcomes] 为空时回落到 [rawAccuracy]。
  double get recentAccuracy {
    if (recentOutcomes.isEmpty) {
      return rawAccuracy;
    }
    var hits = 0;
    for (final ok in recentOutcomes) {
      if (ok) {
        hits++;
      }
    }
    return hits / recentOutcomes.length;
  }

  /// 平均响应耗时（毫秒）。
  double averageResponseDuration() =>
      MathUtils.safeDivide(totalResponseMs, totalCount);

  /// 平均重播次数。
  double get averageReplays => MathUtils.safeDivide(replayCount, totalCount);

  /// 是否从未练过。
  bool get isEmpty => totalCount == 0;

  /// 累加一条作答，返回新对象。
  ///
  /// [attempt] 的 `correctInterval` 必须等于 [interval]，否则说明调用方把作答
  /// 分发错了桶——这是编程错误，按架构 §8.2 直接抛。
  IntervalStatistics withAttempt(TrainingAttempt attempt) {
    if (attempt.correctInterval != interval) {
      throw ArgumentError(
        'attempt.correctInterval (${attempt.correctInterval.storageId}) '
        'does not match this statistics interval (${interval.storageId})',
      );
    }
    final nextRecent = <bool>[...recentOutcomes];
    if (!attempt.isUncertain) {
      nextRecent.add(attempt.isCorrect);
      if (nextRecent.length > kRecentWindow) {
        nextRecent.removeRange(0, nextRecent.length - kRecentWindow);
      }
    }
    return IntervalStatistics(
      interval: interval,
      totalCount: totalCount + 1,
      correctCount: correctCount + (attempt.isCorrect ? 1 : 0),
      firstPlayCorrectCount:
          firstPlayCorrectCount + (attempt.firstPlayCorrect() ? 1 : 0),
      replayCount: replayCount + attempt.replayCount,
      uncertainCount: uncertainCount + (attempt.isUncertain ? 1 : 0),
      totalResponseMs: totalResponseMs + attempt.responseMs,
      lastSeenAt: _laterOf(lastSeenAt, attempt.createdAt),
      byDirection: _bumped(byDirection, attempt.direction, attempt),
      byRootMode: _bumped(byRootMode, attempt.rootMode, attempt),
      byTimbre: _bumped(byTimbre, attempt.timbre, attempt),
      recentOutcomes: List<bool>.unmodifiable(nextRecent),
    );
  }

  static DateTime? _laterOf(DateTime? a, DateTime b) =>
      a == null || b.isAfter(a) ? b : a;

  static Map<K, AccuracyBucket> _bumped<K>(
    Map<K, AccuracyBucket> source,
    K key,
    TrainingAttempt attempt,
  ) {
    final next = Map<K, AccuracyBucket>.of(source);
    next[key] = (next[key] ?? AccuracyBucket.empty).withAttempt(attempt);
    return Map<K, AccuracyBucket>.unmodifiable(next);
  }

  /// 复制并覆盖部分字段。
  IntervalStatistics copyWith({
    IntervalId? interval,
    int? totalCount,
    int? correctCount,
    int? firstPlayCorrectCount,
    int? replayCount,
    int? uncertainCount,
    int? totalResponseMs,
    DateTime? lastSeenAt,
    bool clearLastSeenAt = false,
    Map<PlaybackDirection, AccuracyBucket>? byDirection,
    Map<RootMode, AccuracyBucket>? byRootMode,
    Map<Timbre, AccuracyBucket>? byTimbre,
    List<bool>? recentOutcomes,
  }) =>
      IntervalStatistics(
        interval: interval ?? this.interval,
        totalCount: totalCount ?? this.totalCount,
        correctCount: correctCount ?? this.correctCount,
        firstPlayCorrectCount:
            firstPlayCorrectCount ?? this.firstPlayCorrectCount,
        replayCount: replayCount ?? this.replayCount,
        uncertainCount: uncertainCount ?? this.uncertainCount,
        totalResponseMs: totalResponseMs ?? this.totalResponseMs,
        lastSeenAt: clearLastSeenAt ? null : (lastSeenAt ?? this.lastSeenAt),
        byDirection: byDirection ?? this.byDirection,
        byRootMode: byRootMode ?? this.byRootMode,
        byTimbre: byTimbre ?? this.byTimbre,
        recentOutcomes: recentOutcomes ?? this.recentOutcomes,
      );

  /// 序列化。维度 Map 用枚举 `storageId` 作键，空桶不落盘。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'interval': interval.storageId,
        'total': totalCount,
        'correct': correctCount,
        'firstPlayCorrect': firstPlayCorrectCount,
        'replays': replayCount,
        'uncertain': uncertainCount,
        'responseMs': totalResponseMs,
        if (lastSeenAt != null)
          'lastSeenAt': lastSeenAt!.toUtc().toIso8601String(),
        'byDirection': _encodeBuckets(byDirection, (k) => k.storageId),
        'byRootMode': _encodeBuckets(byRootMode, (k) => k.storageId),
        'byTimbre': _encodeBuckets(byTimbre, (k) => k.storageId),
        'recent': recentOutcomes.toList(growable: false),
      };

  /// 反序列化。
  factory IntervalStatistics.fromJson(Map<String, dynamic> json) {
    final rawRecent = json['recent'];
    final recent = <bool>[];
    if (rawRecent is List) {
      for (final item in rawRecent) {
        recent.add(item == true);
      }
    }
    return IntervalStatistics(
      interval: IntervalId.fromStorageId(json['interval']),
      totalCount: _readInt(json['total']),
      correctCount: _readInt(json['correct']),
      firstPlayCorrectCount: _readInt(json['firstPlayCorrect']),
      replayCount: _readInt(json['replays']),
      uncertainCount: _readInt(json['uncertain']),
      totalResponseMs: _readInt(json['responseMs']),
      lastSeenAt: _readNullableTime(json['lastSeenAt']),
      byDirection: _decodeBuckets(
        json['byDirection'],
        PlaybackDirection.values,
        (v) => v.storageId,
      ),
      byRootMode: _decodeBuckets(
        json['byRootMode'],
        RootMode.values,
        (v) => v.storageId,
      ),
      byTimbre: _decodeBuckets(
        json['byTimbre'],
        Timbre.values,
        (v) => v.storageId,
      ),
      recentOutcomes: List<bool>.unmodifiable(recent),
    );
  }

  static Map<String, dynamic> _encodeBuckets<K>(
    Map<K, AccuracyBucket> source,
    String Function(K key) keyOf,
  ) {
    final out = <String, dynamic>{};
    // 按键名排序落盘，保证同样的数据产生同样的字节，快照测试才可断言。
    final keys = source.keys.toList()
      ..sort((a, b) => keyOf(a).compareTo(keyOf(b)));
    for (final key in keys) {
      final bucket = source[key]!;
      if (!bucket.isEmpty) {
        out[keyOf(key)] = bucket.toJson();
      }
    }
    return out;
  }

  static Map<K, AccuracyBucket> _decodeBuckets<K>(
    Object? raw,
    List<K> values,
    String Function(K value) keyOf,
  ) {
    if (raw is! Map) {
      return Map<K, AccuracyBucket>.unmodifiable(<K, AccuracyBucket>{});
    }
    final out = <K, AccuracyBucket>{};
    for (final entry in raw.entries) {
      for (final candidate in values) {
        if (keyOf(candidate) == entry.key) {
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            out[candidate] = AccuracyBucket.fromJson(value);
          }
          break;
        }
      }
    }
    return Map<K, AccuracyBucket>.unmodifiable(out);
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
        interval,
        totalCount,
        correctCount,
        firstPlayCorrectCount,
        replayCount,
        uncertainCount,
        totalResponseMs,
        lastSeenAt?.toUtc(),
        byDirection,
        byRootMode,
        byTimbre,
        recentOutcomes,
      ];

  @override
  String toString() =>
      'IntervalStatistics(${interval.storageId}, $correctCount/$totalCount)';
}
