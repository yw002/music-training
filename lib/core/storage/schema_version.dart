/// 存储文件级 schema 版本（架构 §8.6 / T15）。
///
/// 与领域模型的 [kDomainSchemaVersion]
/// （`features/training/domain/models/schema_version.dart`）分工：
/// 本文件管「文件级」版本与前向兼容判断，领域文件管「模型级」当前版本。
/// 二者当前都是 1；新版本在这里升，模型级同步升，避免「两个真相」。
library;

/// 当前存储文件 schema 版本。
const int kStorageSchemaVersion = 1;

/// 文件级 schema 名（写进 JSON 顶层的 `schema` 字段，便于与模型级
/// `schemaVersion` 区分，也便于未来多文件共用同一注册表）。
const String kStorageSchemaName = 'interval_ear.storage';

/// 读取文件级 schema 版本；缺失或非数字按 1 处理（前向兼容：低版本能读高版本落的文件）。
int readStorageSchemaVersion(Map<String, dynamic> json) {
  final raw = json['schemaVersion'] ?? json['schema'];
  if (raw is int && raw > 0) {
    return raw;
  }
  if (raw is num && raw > 0) {
    return raw.toInt();
  }
  return 1;
}

/// 版本号高于本程序当前支持的版本（无法向下兼容，应只读不写并告警）。
bool isFutureStorageVersion(int version) => version > kStorageSchemaVersion;
