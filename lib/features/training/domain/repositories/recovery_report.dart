import 'package:equatable/equatable.dart';

/// 一次数据恢复的诊断报告（架构 §4.3 / T16 验收 2）。
///
/// 落盘层在启动时若发现 `stats.json` 损坏或 JSONL 有坏行，会**静默修复**并产出
/// 本报告，UI 只提示一次（不弹错误框、不打断训练）。放在 `domain/repositories`
/// 而非 `data/`，是为了让 `TrainingRepository` 接口（同目录）能引用它而不破坏
/// 「domain 不依赖 data」的分层。
class RecoveryReport extends Equatable {
  /// 创建恢复报告。
  const RecoveryReport({
    this.skippedAttemptLines = 0,
    this.statsRebuilt = false,
    this.recoveredAttempts = 0,
    this.corruptFiles = const <String>[],
  });

  /// JSONL 中被跳过（损坏）的行数。
  final int skippedAttemptLines;

  /// 是否从流水重建了 `stats.json`。
  final bool statsRebuilt;

  /// 重建统计时纳入的作答条数。
  final int recoveredAttempts;

  /// 整体读不出的损坏文件路径。
  final List<String> corruptFiles;

  /// 是否有任何需要提示用户的恢复动作。
  bool get hasRecovery =>
      skippedAttemptLines > 0 || statsRebuilt || corruptFiles.isNotEmpty;

  /// 合并两份报告（多次恢复累加）。
  RecoveryReport merge(RecoveryReport other) => RecoveryReport(
        skippedAttemptLines: skippedAttemptLines + other.skippedAttemptLines,
        statsRebuilt: statsRebuilt || other.statsRebuilt,
        recoveredAttempts: recoveredAttempts + other.recoveredAttempts,
        corruptFiles: <String>[...corruptFiles, ...other.corruptFiles],
      );

  @override
  List<Object?> get props => <Object?>[
        skippedAttemptLines,
        statsRebuilt,
        recoveredAttempts,
        corruptFiles,
      ];
}
