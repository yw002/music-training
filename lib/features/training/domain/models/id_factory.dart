import 'dart:math' as math;

/// 实体 ID 生成（架构 §8.6：`时间戳(ms) + 4 位随机`，**不引入 uuid 包**）。
///
/// 为什么不用 uuid：本项目的 ID 只需要「单机内不重复 + 天然按时间排序 + 人眼
/// 可读出大致时间」，128 位 UUID 既浪费存储又不可排序。时间戳前缀让 JSONL
/// 记录天然有序，排障时一眼能看出是哪天的数据。
///
/// 随机源必须由外部注入（架构 §8.7），测试里注入 `Xorshift32Random(seed)` 后
/// 生成的 ID 完全可复现。
abstract final class IdFactory {
  const IdFactory._();

  /// 随机后缀的位数。
  static const int randomDigits = 4;

  /// 随机后缀的取值上界（不含）。
  static const int randomBound = 10000;

  /// 生成一个 ID：`<prefix>-<epochMs>-<4位随机>`。
  ///
  /// [prefix] 用于人眼区分类型（`q` 题目 / `s` 会话 / `a` 作答）。
  static String next(String prefix, DateTime now, math.Random random) {
    final suffix =
        random.nextInt(randomBound).toString().padLeft(randomDigits, '0');
    return '$prefix-${now.toUtc().millisecondsSinceEpoch}-$suffix';
  }

  /// 题目 ID。
  static String question(DateTime now, math.Random random) =>
      next('q', now, random);

  /// 会话 ID。
  static String session(DateTime now, math.Random random) =>
      next('s', now, random);

  /// 作答 ID。
  static String attempt(DateTime now, math.Random random) =>
      next('a', now, random);
}
