import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 统计重建（T16 验收 1）。
///
/// 纯函数封装 [StatsSnapshot.rebuildFromAttempts]：JSONL 流水是真相源，
/// `stats.json` 删掉后调用它即可还原**完全相同**的快照。单测通过「删 stats.json
/// → rebuild → 与增量结果比对」来验证无第二个真相。
abstract final class StatsRebuilder {
  const StatsRebuilder._();

  /// 从全量流水重算统计快照。
  static StatsSnapshot rebuild(
    List<TrainingAttempt> attempts,
    List<TrainingSession> sessions,
  ) =>
      StatsSnapshot.rebuildFromAttempts(attempts, sessions);
}
