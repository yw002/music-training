import 'package:equatable/equatable.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/stats/accuracy_bucket.dart';

/// 跨音程的「维度」统计（架构 §3.2）。
///
/// 与 [IntervalStatistics] 的分工：那边回答「m6 练得怎么样」，这边回答
/// 「下行是不是普遍比上行差」「完全随机根音是不是明显拖后腿」。报告页的
/// 「维度短板」卡片直接读这里。
///
/// 五个维度都存 [AccuracyBucket]，是因为这些维度天然只有个位数取值，
/// 全量展开也不过二十来个桶，落盘体积可控；而按音程 × 维度做笛卡尔积
/// （13 × 3 × 3 = 117 桶）已经在 [IntervalStatistics] 内部分维度存了，
/// 这里只做全局汇总，不再重复。
class DimensionStatistics extends Equatable {
  /// 创建维度统计。
  const DimensionStatistics({
    this.byDirection = const <PlaybackDirection, AccuracyBucket>{},
    this.byRootMode = const <RootMode, AccuracyBucket>{},
    this.byTimbre = const <Timbre, AccuracyBucket>{},
    this.byAnswerMode = const <AnswerMode, AccuracyBucket>{},
    this.byBucket = const <QuestionBucket, AccuracyBucket>{},
  });

  /// 全空统计。
  static const DimensionStatistics empty = DimensionStatistics();

  /// 按播放方向。
  final Map<PlaybackDirection, AccuracyBucket> byDirection;

  /// 按根音策略。
  final Map<RootMode, AccuracyBucket> byRootMode;

  /// 按音色。
  final Map<Timbre, AccuracyBucket> byTimbre;

  /// 按答题选项策略。
  final Map<AnswerMode, AccuracyBucket> byAnswerMode;

  /// 按题目来源桶。用于回答「热身题是不是明显更差」。
  final Map<QuestionBucket, AccuracyBucket> byBucket;

  /// 取某个方向的桶，缺失时返回 [AccuracyBucket.empty]（不返回 null，
  /// 调用方不必到处判空）。
  AccuracyBucket directionBucket(PlaybackDirection value) =>
      byDirection[value] ?? AccuracyBucket.empty;

  /// 取某个根音策略的桶。
  AccuracyBucket rootModeBucket(RootMode value) =>
      byRootMode[value] ?? AccuracyBucket.empty;

  /// 取某个音色的桶。
  AccuracyBucket timbreBucket(Timbre value) =>
      byTimbre[value] ?? AccuracyBucket.empty;

  /// 取某个答题模式的桶。
  AccuracyBucket answerModeBucket(AnswerMode value) =>
      byAnswerMode[value] ?? AccuracyBucket.empty;

  /// 取某个来源桶的统计。
  AccuracyBucket bucketOf(QuestionBucket value) =>
      byBucket[value] ?? AccuracyBucket.empty;

  /// 是否一条作答都没有。
  bool get isEmpty =>
      byDirection.isEmpty &&
      byRootMode.isEmpty &&
      byTimbre.isEmpty &&
      byAnswerMode.isEmpty &&
      byBucket.isEmpty;

  /// 累加一条作答，返回新对象。
  DimensionStatistics withAttempt(TrainingAttempt attempt) =>
      DimensionStatistics(
        byDirection: _bumped(byDirection, attempt.direction, attempt),
        byRootMode: _bumped(byRootMode, attempt.rootMode, attempt),
        byTimbre: _bumped(byTimbre, attempt.timbre, attempt),
        byAnswerMode: _bumped(byAnswerMode, attempt.answerMode, attempt),
        byBucket: _bumped(byBucket, attempt.bucket, attempt),
      );

  /// 找出正确率最低的方向。样本数不足 [minSamples] 的维度值直接跳过，
  /// 否则「只练过 1 题的和声」会永远霸占短板位。
  ///
  /// 并列时取枚举声明顺序靠前的那个，保证结果稳定可测。
  PlaybackDirection? weakestDirection({int minSamples = 5}) =>
      weakestOf<PlaybackDirection>(byDirection, minSamples: minSamples);

  /// 找出正确率最低的根音策略。
  RootMode? weakestRootMode({int minSamples = 5}) =>
      weakestOf<RootMode>(byRootMode, minSamples: minSamples);

  /// 找出正确率最低的音色。
  Timbre? weakestTimbre({int minSamples = 5}) =>
      weakestOf<Timbre>(byTimbre, minSamples: minSamples);

  /// 通用「最弱维度值」：在样本足够的桶里挑正确率最低的。
  ///
  /// 做成 static 泛型而不是给每个维度各抄一遍循环，是为了让「并列取先声明者」
  /// 这条打破平局的规则只有一份实现。
  static K? weakestOf<K>(Map<K, AccuracyBucket> source, {int minSamples = 5}) {
    K? best;
    double? bestAccuracy;
    for (final entry in source.entries) {
      final bucket = entry.value;
      if (bucket.effectiveTotal < minSamples) {
        continue;
      }
      final accuracy = bucket.accuracy();
      if (bestAccuracy == null || accuracy < bestAccuracy) {
        bestAccuracy = accuracy;
        best = entry.key;
      }
    }
    return best;
  }

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
  DimensionStatistics copyWith({
    Map<PlaybackDirection, AccuracyBucket>? byDirection,
    Map<RootMode, AccuracyBucket>? byRootMode,
    Map<Timbre, AccuracyBucket>? byTimbre,
    Map<AnswerMode, AccuracyBucket>? byAnswerMode,
    Map<QuestionBucket, AccuracyBucket>? byBucket,
  }) => DimensionStatistics(
    byDirection: byDirection ?? this.byDirection,
    byRootMode: byRootMode ?? this.byRootMode,
    byTimbre: byTimbre ?? this.byTimbre,
    byAnswerMode: byAnswerMode ?? this.byAnswerMode,
    byBucket: byBucket ?? this.byBucket,
  );

  /// 序列化。键用枚举 `storageId`，空桶不落盘。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'byDirection': encodeBuckets(byDirection, (k) => k.storageId),
    'byRootMode': encodeBuckets(byRootMode, (k) => k.storageId),
    'byTimbre': encodeBuckets(byTimbre, (k) => k.storageId),
    'byAnswerMode': encodeBuckets(byAnswerMode, (k) => k.storageId),
    'byBucket': encodeBuckets(byBucket, (k) => k.storageId),
  };

  /// 反序列化。未知键（高版本写入的新枚举值）静默丢弃。
  factory DimensionStatistics.fromJson(Map<String, dynamic> json) =>
      DimensionStatistics(
        byDirection: decodeBuckets(
          json['byDirection'],
          PlaybackDirection.values,
          (v) => v.storageId,
        ),
        byRootMode: decodeBuckets(
          json['byRootMode'],
          RootMode.values,
          (v) => v.storageId,
        ),
        byTimbre: decodeBuckets(
          json['byTimbre'],
          Timbre.values,
          (v) => v.storageId,
        ),
        byAnswerMode: decodeBuckets(
          json['byAnswerMode'],
          AnswerMode.values,
          (v) => v.storageId,
        ),
        byBucket: decodeBuckets(
          json['byBucket'],
          QuestionBucket.values,
          (v) => v.storageId,
        ),
      );

  /// 把 `枚举 -> 桶` 编码成 `字符串 -> JSON`。按键名排序，保证字节稳定。
  ///
  /// 公开给 [IntervalStatistics] 之外的统计类复用（它有自己的私有副本，
  /// 是历史遗留，后续可统一到这里）。
  static Map<String, dynamic> encodeBuckets<K>(
    Map<K, AccuracyBucket> source,
    String Function(K key) keyOf,
  ) {
    final out = <String, dynamic>{};
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

  /// [encodeBuckets] 的逆操作。
  static Map<K, AccuracyBucket> decodeBuckets<K>(
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

  @override
  List<Object?> get props => <Object?>[
    byDirection,
    byRootMode,
    byTimbre,
    byAnswerMode,
    byBucket,
  ];

  @override
  String toString() =>
      'DimensionStatistics('
      'dir=${byDirection.length}, root=${byRootMode.length}, '
      'timbre=${byTimbre.length}, answer=${byAnswerMode.length}, '
      'bucket=${byBucket.length})';
}
