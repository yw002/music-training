import 'package:equatable/equatable.dart';
import 'package:interval_ear/core/utils/math_utils.dart';
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/stats/accuracy_bucket.dart';

/// 二选一强化训练中，单个音程对的统计（架构 §3.2）。
///
/// 它回答的问题和 [IntervalStatistics] 不同：后者是「m6 单独出现时听得准不准」，
/// 这里是「m6 和 M6 摆在一起时能不能分清」——很多用户在 13 选 1 里对 m6 有
/// 六成正确率，但在 m6/M6 二选一里接近抛硬币，这才是真正的短板。
///
/// [bySide] 按**正确答案落在哪一侧**拆分。这是二选一模式的核心诊断：
/// 如果「正确答案是 m6」时正确率 0.9、「正确答案是 M6」时只有 0.3，
/// 说明用户其实是「一律猜 m6」，整体 0.6 的正确率是假象。
class PairStatistics extends Equatable {
  /// 创建音程对统计。[pair] 会被规范化（低半音数在前）。
  PairStatistics({
    required IntervalPair pair,
    this.totalCount = 0,
    this.correctCount = 0,
    this.uncertainCount = 0,
    this.replayCount = 0,
    this.totalResponseMs = 0,
    this.lastPracticedAt,
    Map<IntervalId, AccuracyBucket>? bySide,
    List<bool>? recentOutcomes,
  }) : pair = pair.normalized(),
       bySide = Map<IntervalId, AccuracyBucket>.unmodifiable(
         bySide ?? const <IntervalId, AccuracyBucket>{},
       ),
       recentOutcomes = List<bool>.unmodifiable(
         recentOutcomes ?? const <bool>[],
       );

  /// 该音程对的空统计。
  factory PairStatistics.empty(IntervalPair pair) => PairStatistics(pair: pair);

  /// 音程对（已规范化）。
  final IntervalPair pair;

  /// 总作答数（含「不确定」）。
  final int totalCount;

  /// 答对数。
  final int correctCount;

  /// 「不确定」数。
  final int uncertainCount;

  /// 累计重播次数。
  final int replayCount;

  /// 累计响应耗时（毫秒）。
  final int totalResponseMs;

  /// 最近一次练习时刻。
  final DateTime? lastPracticedAt;

  /// 按「正确答案在哪一侧」拆分的桶。
  final Map<IntervalId, AccuracyBucket> bySide;

  /// 最近 [kPairRecentOutcomeCapacity] 次**有效**作答是否答对，末尾最新。
  final List<bool> recentOutcomes;

  /// 有效作答数（剔除「不确定」）。
  int get effectiveCount {
    final n = totalCount - uncertainCount;
    return n < 0 ? 0 : n;
  }

  /// 是否从未练过。
  bool get isEmpty => totalCount == 0;

  /// 整体正确率 `[0, 1]`。
  double get accuracy => MathUtils.safeDivide(correctCount, effectiveCount);

  /// 近期正确率 `[0, 1]`；无近期记录时回落到 [accuracy]。
  double get recentAccuracy {
    if (recentOutcomes.isEmpty) {
      return accuracy;
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
  double get averageResponseMs =>
      MathUtils.safeDivide(totalResponseMs, totalCount);

  /// 取某一侧的桶，缺失返回 [AccuracyBucket.empty]。
  AccuracyBucket sideBucket(IntervalId side) =>
      bySide[side] ?? AccuracyBucket.empty;

  /// 两侧正确率之差的绝对值 `[0, 1]`。
  ///
  /// 越接近 1 说明用户越像「固定猜一边」；报告页据此提示
  /// 「你在这一对上倾向于总选 X」。任一侧无有效样本时返回 0。
  double get sideBias {
    final low = sideBucket(pair.low);
    final high = sideBucket(pair.high);
    if (low.effectiveTotal == 0 || high.effectiveTotal == 0) {
      return 0;
    }
    return (low.accuracy() - high.accuracy()).abs();
  }

  /// 两侧出题数是否大致均衡（差值不超过总数的 1/4）。
  ///
  /// 用于自检 `BinaryAnswerBalancer`：如果它工作正常，长期看两侧应当接近 1:1。
  bool get isSideBalanced {
    final low = sideBucket(pair.low).total;
    final high = sideBucket(pair.high).total;
    final sum = low + high;
    if (sum == 0) {
      return true;
    }
    return (low - high).abs() * 4 <= sum;
  }

  /// 累加一条作答，返回新对象。
  ///
  /// [attempt] 的 `correctInterval` 必须落在本对内，否则是调用方分派错误，
  /// 按架构 §8.2 直接抛（编程错误不做静默降级）。
  PairStatistics withAttempt(TrainingAttempt attempt) {
    if (!pair.contains(attempt.correctInterval)) {
      throw ArgumentError(
        'attempt.correctInterval (${attempt.correctInterval.storageId}) '
        'is not part of pair ${pair.key()}',
      );
    }
    final nextRecent = <bool>[...recentOutcomes];
    if (!attempt.isUncertain) {
      nextRecent.add(attempt.isCorrect);
      if (nextRecent.length > kPairRecentOutcomeCapacity) {
        nextRecent.removeRange(
          0,
          nextRecent.length - kPairRecentOutcomeCapacity,
        );
      }
    }
    final nextBySide = Map<IntervalId, AccuracyBucket>.of(bySide);
    nextBySide[attempt.correctInterval] = sideBucket(
      attempt.correctInterval,
    ).withAttempt(attempt);
    return PairStatistics(
      pair: pair,
      totalCount: totalCount + 1,
      correctCount: correctCount + (attempt.isCorrect ? 1 : 0),
      uncertainCount: uncertainCount + (attempt.isUncertain ? 1 : 0),
      replayCount: replayCount + attempt.replayCount,
      totalResponseMs: totalResponseMs + attempt.responseMs,
      lastPracticedAt: _laterOf(lastPracticedAt, attempt.createdAt),
      bySide: nextBySide,
      recentOutcomes: nextRecent,
    );
  }

  static DateTime? _laterOf(DateTime? a, DateTime b) =>
      a == null || b.isAfter(a) ? b : a;

  /// 复制并覆盖部分字段。
  PairStatistics copyWith({
    IntervalPair? pair,
    int? totalCount,
    int? correctCount,
    int? uncertainCount,
    int? replayCount,
    int? totalResponseMs,
    DateTime? lastPracticedAt,
    bool clearLastPracticedAt = false,
    Map<IntervalId, AccuracyBucket>? bySide,
    List<bool>? recentOutcomes,
  }) => PairStatistics(
    pair: pair ?? this.pair,
    totalCount: totalCount ?? this.totalCount,
    correctCount: correctCount ?? this.correctCount,
    uncertainCount: uncertainCount ?? this.uncertainCount,
    replayCount: replayCount ?? this.replayCount,
    totalResponseMs: totalResponseMs ?? this.totalResponseMs,
    lastPracticedAt: clearLastPracticedAt
        ? null
        : (lastPracticedAt ?? this.lastPracticedAt),
    bySide: bySide ?? this.bySide,
    recentOutcomes: recentOutcomes ?? this.recentOutcomes,
  );

  /// 序列化。
  Map<String, dynamic> toJson() {
    final sides = <String, dynamic>{};
    final keys = bySide.keys.toList()
      ..sort((a, b) => a.semitones.compareTo(b.semitones));
    for (final key in keys) {
      final bucket = bySide[key]!;
      if (!bucket.isEmpty) {
        sides[key.storageId] = bucket.toJson();
      }
    }
    return <String, dynamic>{
      'pair': pair.key(),
      'total': totalCount,
      'correct': correctCount,
      'uncertain': uncertainCount,
      'replays': replayCount,
      'responseMs': totalResponseMs,
      if (lastPracticedAt != null)
        'lastPracticedAt': lastPracticedAt!.toUtc().toIso8601String(),
      'bySide': sides,
      'recent': recentOutcomes.toList(growable: false),
    };
  }

  /// 反序列化。`pair` 非法时降级为 `P1|P1`（退化对），不抛异常。
  factory PairStatistics.fromJson(Map<String, dynamic> json) {
    final rawPair = json['pair'];
    final pair = rawPair is String
        ? (IntervalPair.tryFromKey(rawPair) ??
              const IntervalPair(
                IntervalId.perfectUnison,
                IntervalId.perfectUnison,
              ))
        : const IntervalPair(
            IntervalId.perfectUnison,
            IntervalId.perfectUnison,
          );

    final sides = <IntervalId, AccuracyBucket>{};
    final rawSides = json['bySide'];
    if (rawSides is Map) {
      for (final entry in rawSides.entries) {
        final id = IntervalId.tryFromStorageId(entry.key);
        final value = entry.value;
        if (id != null && value is Map<String, dynamic>) {
          sides[id] = AccuracyBucket.fromJson(value);
        }
      }
    }

    final recent = <bool>[];
    final rawRecent = json['recent'];
    if (rawRecent is List) {
      for (final item in rawRecent) {
        recent.add(item == true);
      }
    }

    return PairStatistics(
      pair: pair,
      totalCount: _readInt(json['total']),
      correctCount: _readInt(json['correct']),
      uncertainCount: _readInt(json['uncertain']),
      replayCount: _readInt(json['replays']),
      totalResponseMs: _readInt(json['responseMs']),
      lastPracticedAt: _readNullableTime(json['lastPracticedAt']),
      bySide: sides,
      recentOutcomes: recent,
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
    pair,
    totalCount,
    correctCount,
    uncertainCount,
    replayCount,
    totalResponseMs,
    lastPracticedAt?.toUtc(),
    bySide,
    recentOutcomes,
  ];

  @override
  String toString() =>
      'PairStatistics(${pair.key()}, $correctCount/$totalCount)';
}
