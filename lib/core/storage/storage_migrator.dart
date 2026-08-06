import 'package:interval_ear/core/storage/schema_version.dart';
import 'package:interval_ear/core/utils/app_logger.dart';

/// 存储迁移与版本前向兼容（T15 验收 4）。
///
/// 当前只有 v1（与领域级 [kDomainSchemaVersion] 同源），这里预留迁移链骨架：
/// 将来 `kStorageSchemaVersion` 升到 v2 时，在 [migrateToCurrent] 里追加一条
/// `v1 → v2` 的转换步骤即可，调用方零改动。
abstract final class StorageMigrator {
  const StorageMigrator._();

  /// 读取并归一化文件级 schema 版本：缺失或非数字按 v1。
  static int normalizeVersion(Map<String, dynamic> json) =>
      readStorageSchemaVersion(json);

  /// 是否为「未来版本」：版本号高于当前，应只读不写。
  static bool isFuture(Map<String, dynamic> json) =>
      isFutureStorageVersion(readStorageSchemaVersion(json));

  /// 把它升级/归一化到当前可写版本。当前 v1 为 no-op。
  static Map<String, dynamic> migrateToCurrent(Map<String, dynamic> json) {
    final version = readStorageSchemaVersion(json);
    if (version >= kStorageSchemaVersion) {
      return json;
    }
    // 未来的迁移步骤注册在这里（v1→v2→…）。
    AppLogger.info(
      'migrating storage v$version -> v$kStorageSchemaVersion',
      tag: 'StorageMigrator',
    );
    return json;
  }

  /// 遇到未来版本时告警（只读不写，T15 验收 4）。
  static void warnIfFuture(Map<String, dynamic> json) {
    if (isFuture(json)) {
      AppLogger.warning(
        'storage v${readStorageSchemaVersion(json)} newer than supported '
        'v$kStorageSchemaVersion; opening read-only',
        tag: 'StorageMigrator',
      );
    }
  }
}
