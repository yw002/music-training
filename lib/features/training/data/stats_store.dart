import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/storage/json_file_store.dart';
import 'package:interval_ear/features/training/data/stats_dto.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/stats/stats_snapshot.dart';

/// 内存统计快照 + 落盘（T16 验收 1 / 3）。
///
/// [snapshot] 是唯一权威的内存态；每答一题 [applyAttempt] 增量更新，
/// 只在 [persist] 时才把整份写进 `stats.json`（增量更新，不每条重写）。
class StatsStore {
  /// 创建统计存储。
  StatsStore({required this.fileStore, this.fileName = AppConfig.statsFileName});

  /// 底层文件存储（同目录下的 `stats.json`）。
  final JsonFileStore fileStore;

  /// 落盘文件名。
  final String fileName;

  StatsSnapshot _snapshot = StatsSnapshot.empty();
  bool _loaded = false;

  /// 当前内存统计快照（不可变视图）。
  StatsSnapshot get snapshot => _snapshot;

  /// 从 `stats.json` 加载（只做一次；不存在则保持空快照）。
  Future<void> init() async {
    if (_loaded) {
      return;
    }
    final json = await fileStore.read(fileName);
    if (json != null) {
      _snapshot = StatsSnapshot.fromJson(json);
    }
    _loaded = true;
  }

  /// 增量应用一条作答。
  void applyAttempt(TrainingAttempt attempt) {
    _snapshot = _snapshot.withAttempt(attempt);
  }

  /// 增量应用一个已结算会话。
  void applySession(TrainingSession session) {
    _snapshot = _snapshot.withSession(session);
  }

  /// 从全量流水重建统计（T16 验收 1）。
  Future<StatsSnapshot> rebuildFromAttempts(
    List<TrainingAttempt> attempts,
    List<TrainingSession> sessions,
  ) async {
    _snapshot = StatsSnapshot.rebuildFromAttempts(attempts, sessions);
    return _snapshot;
  }

  /// 落盘当前快照（原子写）。
  Future<void> persist() async {
    await fileStore.writeAtomic(fileName, StatsDto(_snapshot).toJson());
  }

  /// 清空内存状态（清空数据用，幂等）。
  void reset() {
    _snapshot = StatsSnapshot.empty();
    _loaded = true;
  }
}
