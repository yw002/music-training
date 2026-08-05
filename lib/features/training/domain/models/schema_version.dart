/// 领域模型的落盘 schema 版本（架构 §8.6）。
///
/// 每个落盘模型的 JSON 顶层都带 `schemaVersion:int`，缺失按 1 处理。
///
/// **与 `core/storage/schema.dart` 的关系**：那个文件（T08）负责「文件级」的
/// schema 名与迁移链注册表；这里是「模型级」的当前版本号，是迁移链的终点。
/// T08 落地时应当直接引用本常量，**不要再定义一个平行的版本号**，否则迁移
/// 判断会出现两个真相。
library;

/// 当前领域模型版本。任何字段的**语义变更**或**删除**都要 +1 并写迁移；
/// 纯粹新增可选字段（有默认值）不需要升版本。
const int kDomainSchemaVersion = 1;

/// 从 JSON 顶层读取 schema 版本，缺失或非法按 1 处理。
int readSchemaVersion(Map<String, dynamic> json) {
  final raw = json['schemaVersion'];
  if (raw is int && raw > 0) {
    return raw;
  }
  if (raw is num && raw > 0) {
    return raw.toInt();
  }
  return 1;
}
