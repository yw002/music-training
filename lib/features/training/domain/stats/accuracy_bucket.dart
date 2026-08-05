import 'package:equatable/equatable.dart';
import 'package:interval_ear/core/utils/math_utils.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';

/// 一个维度切片下的作答计数（架构 §3.2）。
///
/// 「维度」可以是方向、根音策略、音色，也可以是某个音程本身。所有统计口径都
/// 复用这一个结构，保证「按方向的正确率」和「按音色的正确率」算法完全一致。
///
/// 全部字段都是**可加的计数**，没有派生比率——比率只在 getter 里现算。这样
/// 增量更新（`withAttempt`）与全量重算（`fold(merge)`）必然得到同一结果，
/// 也就不存在「增量统计漂移」这种最难查的 bug。
class AccuracyBucket extends Equatable {
  /// 创建一个计数桶。
  const AccuracyBucket({
    this.total = 0,
    this.correct = 0,
    this.firstPlayCorrect = 0,
    this.uncertain = 0,
    this.replays = 0,
    this.totalResponseMs = 0,
  });

  /// 空桶常量。
  static const AccuracyBucket empty = AccuracyBucket();

  /// 总作答数（含「不确定」）。
  final int total;

  /// 答对数。
  final int correct;

  /// 首播即答对数（`replayCount == 0` 且答对）。
  final int firstPlayCorrect;

  /// 「不确定」次数。
  final int uncertain;

  /// 累计重播次数。
  final int replays;

  /// 累计响应耗时（毫秒）。
  final int totalResponseMs;

  /// 有效作答数：剔除「不确定」后的样本量，即 §5.1 公式里的 `n`。
  int get effectiveTotal {
    final n = total - uncertain;
    return n < 0 ? 0 : n;
  }

  /// 正确率 `[0, 1]`，分母为 [effectiveTotal]；无有效样本时为 0。
  double accuracy() => MathUtils.safeDivide(correct, effectiveTotal);

  /// 首播正确率 `[0, 1]`。
  double firstPlayAccuracy() =>
      MathUtils.safeDivide(firstPlayCorrect, effectiveTotal);

  /// 平均重播次数（分母用 [total]，因为「不确定」的题也会重播）。
  double avgReplays() => MathUtils.safeDivide(replays, total);

  /// 平均响应耗时（毫秒）。
  double avgResponseMs() => MathUtils.safeDivide(totalResponseMs, total);

  /// 是否没有任何数据。
  bool get isEmpty => total == 0;

  /// 合并两个桶（全量重算时用）。
  AccuracyBucket merge(AccuracyBucket other) => AccuracyBucket(
        total: total + other.total,
        correct: correct + other.correct,
        firstPlayCorrect: firstPlayCorrect + other.firstPlayCorrect,
        uncertain: uncertain + other.uncertain,
        replays: replays + other.replays,
        totalResponseMs: totalResponseMs + other.totalResponseMs,
      );

  /// 累加一条作答（增量更新时用）。
  AccuracyBucket withAttempt(TrainingAttempt attempt) => AccuracyBucket(
        total: total + 1,
        correct: correct + (attempt.isCorrect ? 1 : 0),
        firstPlayCorrect: firstPlayCorrect + (attempt.firstPlayCorrect() ? 1 : 0),
        uncertain: uncertain + (attempt.isUncertain ? 1 : 0),
        replays: replays + attempt.replayCount,
        totalResponseMs: totalResponseMs + attempt.responseMs,
      );

  /// 复制并覆盖部分字段。
  AccuracyBucket copyWith({
    int? total,
    int? correct,
    int? firstPlayCorrect,
    int? uncertain,
    int? replays,
    int? totalResponseMs,
  }) =>
      AccuracyBucket(
        total: total ?? this.total,
        correct: correct ?? this.correct,
        firstPlayCorrect: firstPlayCorrect ?? this.firstPlayCorrect,
        uncertain: uncertain ?? this.uncertain,
        replays: replays ?? this.replays,
        totalResponseMs: totalResponseMs ?? this.totalResponseMs,
      );

  /// 序列化。用短键名——混淆矩阵之外，这是落盘体积最大的结构。
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': total,
        'c': correct,
        'f': firstPlayCorrect,
        'u': uncertain,
        'r': replays,
        'ms': totalResponseMs,
      };

  /// 反序列化。
  factory AccuracyBucket.fromJson(Map<String, dynamic> json) => AccuracyBucket(
        total: _readInt(json['t']),
        correct: _readInt(json['c']),
        firstPlayCorrect: _readInt(json['f']),
        uncertain: _readInt(json['u']),
        replays: _readInt(json['r']),
        totalResponseMs: _readInt(json['ms']),
      );

  static int _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return 0;
  }

  @override
  List<Object?> get props => <Object?>[
        total,
        correct,
        firstPlayCorrect,
        uncertain,
        replays,
        totalResponseMs,
      ];

  @override
  String toString() => 'AccuracyBucket($correct/$total)';
}
