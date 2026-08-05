import 'package:equatable/equatable.dart';
import 'package:interval_ear/core/utils/math_utils.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';

/// `yyyy-MM-dd` 日期键的解析与运算。
///
/// **为什么不直接用 `DateTime`**：连续打卡要回答的是「用户主观上的第几天」，
/// 而 `DateTime` 的加减会被夏令时和时区偏移干扰（`2024-03-10 + 24h` 在美东是
/// 3 月 11 日凌晨 1 点，但在冬夏令时切换日会变成 3 月 10 日 23 点）。
/// 这里的做法是：**只在生成 key 的那一刻用本地时区**，之后所有加减都在
/// UTC 午夜锚点上做整数天运算，彻底避开 DST。
abstract final class DateKeys {
  const DateKeys._();

  /// 日期键的字符长度（`yyyy-MM-dd`）。
  static const int keyLength = 10;

  /// 把一个时刻转成**本地**日期键。
  static String of(DateTime time) {
    final local = time.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  /// 把日期键解析成 UTC 午夜锚点，用于整数天运算。非法输入返回 `null`。
  static DateTime? parse(String key) {
    if (key.length != keyLength) {
      return null;
    }
    final year = int.tryParse(key.substring(0, 4));
    final month = int.tryParse(key.substring(5, 7));
    final day = int.tryParse(key.substring(8, 10));
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final anchor = DateTime.utc(year, month, day);
    // 排除 2 月 31 日这类会被 DateTime 静默滚动到下个月的输入。
    if (anchor.month != month || anchor.day != day) {
      return null;
    }
    return anchor;
  }

  /// 是否是合法日期键。
  static bool isValid(String key) => parse(key) != null;

  /// 日期键加减天数。非法输入原样返回。
  static String addDays(String key, int days) {
    final anchor = parse(key);
    if (anchor == null) {
      return key;
    }
    return of(anchor.add(Duration(days: days)).toUtc());
  }

  /// `to - from` 的天数。任一非法返回 `null`。
  static int? differenceInDays(String from, String to) {
    final a = parse(from);
    final b = parse(to);
    if (a == null || b == null) {
      return null;
    }
    return b.difference(a).inDays;
  }

  /// 两个日期键在时间轴上的先后比较，可直接传给 `List.sort`。
  ///
  /// 由于 `yyyy-MM-dd` 是零填充的定宽格式，字典序即时间序，直接比字符串
  /// 就够了——但显式命名一个比较器，可以避免调用方自己写 `a.compareTo(b)`
  /// 时误用在别的字段上。
  static int compare(String a, String b) => a.compareTo(b);
}

/// 单日汇总（架构 §3.2）。趋势折线图与连续打卡都基于它。
///
/// **正确率口径**：与结算页一致，「不确定」计入分母、不计入分子（用户看到的
/// 是真实完成度）。需要剔除不确定的口径请用 [effectiveAccuracy]。
class DailySummary extends Equatable {
  /// 创建单日汇总。
  const DailySummary({
    required this.dateKey,
    this.sessionCount = 0,
    this.questionCount = 0,
    this.correctCount = 0,
    this.uncertainCount = 0,
    this.replayCount = 0,
    this.totalResponseMs = 0,
    this.practiceMs = 0,
    this.maxCombo = 0,
  });

  /// 为某个时刻所在的**本地**日期创建一条空汇总。
  factory DailySummary.forDate(DateTime time) =>
      DailySummary(dateKey: DateKeys.of(time));

  /// 本地日期键 `yyyy-MM-dd`。
  final String dateKey;

  /// 当天完成的会话数。
  final int sessionCount;

  /// 当天作答题数（含「不确定」）。
  final int questionCount;

  /// 当天答对数。
  final int correctCount;

  /// 当天「不确定」数。
  final int uncertainCount;

  /// 当天累计重播次数。
  final int replayCount;

  /// 当天累计答题耗时（毫秒）。
  final int totalResponseMs;

  /// 当天累计练习时长（毫秒），来自会话的 `duration`。
  ///
  /// 与 [totalResponseMs] 的区别：后者只统计「题目就绪到提交」，不含看反馈、
  /// 中途暂停的时间，因此练习时长恒 ≥ 答题耗时。
  final int practiceMs;

  /// 当天最高连击。
  final int maxCombo;

  /// 当天是否有练习记录。
  bool get isActive => questionCount > 0;

  /// 是否是一条空汇总。
  bool get isEmpty => questionCount == 0 && sessionCount == 0;

  /// 有效作答数（剔除「不确定」）。
  int get effectiveCount {
    final n = questionCount - uncertainCount;
    return n < 0 ? 0 : n;
  }

  /// 展示口径正确率：`correct / question`，「不确定」算未答对。
  double get accuracy => MathUtils.safeDivide(correctCount, questionCount);

  /// 能力口径正确率：`correct / (question - uncertain)`。
  double get effectiveAccuracy =>
      MathUtils.safeDivide(correctCount, effectiveCount);

  /// 平均每题耗时（毫秒）。
  double get averageResponseMs =>
      MathUtils.safeDivide(totalResponseMs, questionCount);

  /// 练习时长。
  Duration get practiceDuration => Duration(milliseconds: practiceMs);

  /// UTC 午夜锚点；[dateKey] 非法时返回 `null`。
  DateTime? get anchor => DateKeys.parse(dateKey);

  /// 累加一条作答。调用方需保证 [attempt] 属于本日（由 `StatsSnapshot` 分派）。
  DailySummary withAttempt(TrainingAttempt attempt) => copyWith(
    questionCount: questionCount + 1,
    correctCount: correctCount + (attempt.isCorrect ? 1 : 0),
    uncertainCount: uncertainCount + (attempt.isUncertain ? 1 : 0),
    replayCount: replayCount + attempt.replayCount,
    totalResponseMs: totalResponseMs + attempt.responseMs,
  );

  /// 累加一次**已完成**的会话。
  ///
  /// 只累加会话级字段（场次、时长、最高连击）；题目与正确数由 [withAttempt]
  /// 负责，避免同一批数据被算两次。
  DailySummary withSession(TrainingSession session) => copyWith(
    sessionCount: sessionCount + 1,
    practiceMs: practiceMs + (session.duration?.inMilliseconds ?? 0),
    maxCombo: session.maxCombo > maxCombo ? session.maxCombo : maxCombo,
  );

  /// 合并同一天的两条汇总。[dateKey] 取本对象的。
  DailySummary merge(DailySummary other) => DailySummary(
    dateKey: dateKey,
    sessionCount: sessionCount + other.sessionCount,
    questionCount: questionCount + other.questionCount,
    correctCount: correctCount + other.correctCount,
    uncertainCount: uncertainCount + other.uncertainCount,
    replayCount: replayCount + other.replayCount,
    totalResponseMs: totalResponseMs + other.totalResponseMs,
    practiceMs: practiceMs + other.practiceMs,
    maxCombo: other.maxCombo > maxCombo ? other.maxCombo : maxCombo,
  );

  /// 复制并覆盖部分字段。
  DailySummary copyWith({
    String? dateKey,
    int? sessionCount,
    int? questionCount,
    int? correctCount,
    int? uncertainCount,
    int? replayCount,
    int? totalResponseMs,
    int? practiceMs,
    int? maxCombo,
  }) => DailySummary(
    dateKey: dateKey ?? this.dateKey,
    sessionCount: sessionCount ?? this.sessionCount,
    questionCount: questionCount ?? this.questionCount,
    correctCount: correctCount ?? this.correctCount,
    uncertainCount: uncertainCount ?? this.uncertainCount,
    replayCount: replayCount ?? this.replayCount,
    totalResponseMs: totalResponseMs ?? this.totalResponseMs,
    practiceMs: practiceMs ?? this.practiceMs,
    maxCombo: maxCombo ?? this.maxCombo,
  );

  /// 序列化。短键名，趋势图要存 365 天，键名长度直接乘 365。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'd': dateKey,
    's': sessionCount,
    'q': questionCount,
    'c': correctCount,
    'u': uncertainCount,
    'r': replayCount,
    'ms': totalResponseMs,
    'pms': practiceMs,
    'combo': maxCombo,
  };

  /// 反序列化。
  factory DailySummary.fromJson(Map<String, dynamic> json) => DailySummary(
    dateKey: json['d'] as String? ?? '',
    sessionCount: _readInt(json['s']),
    questionCount: _readInt(json['q']),
    correctCount: _readInt(json['c']),
    uncertainCount: _readInt(json['u']),
    replayCount: _readInt(json['r']),
    totalResponseMs: _readInt(json['ms']),
    practiceMs: _readInt(json['pms']),
    maxCombo: _readInt(json['combo']),
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

  /// 按日期升序的比较器。
  static int compareByDate(DailySummary a, DailySummary b) =>
      DateKeys.compare(a.dateKey, b.dateKey);

  @override
  List<Object?> get props => <Object?>[
    dateKey,
    sessionCount,
    questionCount,
    correctCount,
    uncertainCount,
    replayCount,
    totalResponseMs,
    practiceMs,
    maxCombo,
  ];

  @override
  String toString() =>
      'DailySummary($dateKey, $correctCount/$questionCount, $sessionCount 组)';
}
