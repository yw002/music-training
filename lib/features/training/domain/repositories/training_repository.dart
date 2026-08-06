import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/repositories/recovery_report.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 训练数据仓储接口（架构 §3.5 / T16）。
///
/// JSONL 是唯一真相源；`stats.json` 是可重建缓存（T16 验收 1）。
/// 实现见 `data/training_repository_impl.dart`。
abstract class TrainingRepository {
  /// 记录一次会话开始（追加 JSONL）。
  Future<void> startSession(TrainingSession session);

  /// 记录一条作答（JSONL 追加 + 内存统计增量，不重写 stats.json）。
  Future<void> recordAttempt(TrainingAttempt attempt);

  /// 会话结算（追加 session + 落盘 stats.json）。
  Future<void> finishSession(TrainingSession session);

  /// 加载最新统计快照（必要时从流水重建）。
  Future<StatsSnapshot> loadStats();

  /// 统计变化流（内存增量后即时 emit，供 UI 订阅）。
  Stream<StatsSnapshot> get statsChanges;

  /// 最近 [limit] 个已结算会话（按开始时间倒序）。
  Future<List<TrainingSession>> recentSessions(int limit);

  /// [from, to] 区间内的作答流水。
  Future<List<TrainingAttempt>> attemptsInRange(DateTime from, DateTime to);

  /// 取走一次性的恢复报告（取后清空）。
  Future<RecoveryReport?> takeRecoveryReport();

  /// 清空全部训练数据（幂等）。
  Future<void> clearAll();

  /// 导出训练数据为单文件 JSON 字符串（可被导入还原）。
  Future<String> exportJson();

  /// 从单文件 JSON 字符串导入并替换全部训练数据（含结构校验）。
  ///
  /// 会清空现有流水与统计，按流水分片规则重新写入导入的 attempts/sessions，
  /// 并重建 stats 缓存，保证内存与 `stats.json` 一致。校验失败
  /// （schema 不符 / JSON 损坏）抛 [FormatException]，调用方负责转换为用户提示文案。
  Future<void> importJson(String json);

  /// 强制落盘内存统计。
  Future<void> flush();
}
