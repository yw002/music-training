// 存储 schema 版本与前向兼容（T15 验收 4）。
//
// 覆盖点：
//  - 当前存储文件 schema 版本为 1；
//  - readStorageSchemaVersion：缺失/非法按 1，合法值按原值；
//  - isFutureStorageVersion：高于当前为 true；
//  - StorageMigrator.migrateToCurrent 在 v1 为 identity（不修改原对象）；
//  - StorageMigrator.isFuture / warnIfFuture 对高版本正确识别且不抛。

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/storage/schema_version.dart';
import 'package:interval_ear/core/storage/storage_migrator.dart';

void main() {
  group('SchemaVersion / StorageMigrator（T15 验收 4）', () {
    test('当前存储文件 schema 版本为 1', () {
      expect(kStorageSchemaVersion, 1);
    });

    test('readStorageSchemaVersion：缺失/非法按 1，合法按原值', () {
      expect(readStorageSchemaVersion(<String, dynamic>{}), 1);
      expect(readStorageSchemaVersion(<String, dynamic>{'schemaVersion': 5}), 5);
      expect(readStorageSchemaVersion(<String, dynamic>{'schema': 3}), 3);
      expect(readStorageSchemaVersion(<String, dynamic>{'schemaVersion': 'x'}), 1);
      expect(readStorageSchemaVersion(<String, dynamic>{'schemaVersion': 0}), 1);
    });

    test('isFutureStorageVersion：高于当前为 true', () {
      expect(isFutureStorageVersion(2), isTrue);
      expect(isFutureStorageVersion(1), isFalse);
      expect(isFutureStorageVersion(0), isFalse);
    });

    test('StorageMigrator.migrateToCurrent 在 v1 为 identity（不修改原对象）', () {
      final json = <String, dynamic>{'schemaVersion': 1, 'x': 1};
      final out = StorageMigrator.migrateToCurrent(json);
      // 当前版本下必须是 no-op：返回同一对象引用，内容不变。
      expect(identical(out, json), isTrue);
      expect(out, json);
    });

    test('StorageMigrator.migrateToCurrent 对高版本保持原样（只读不写）', () {
      final json = <String, dynamic>{'schemaVersion': 9, 'x': 1};
      final out = StorageMigrator.migrateToCurrent(json);
      expect(out['schemaVersion'], 9);
    });

    test('StorageMigrator.isFuture 对高/低版本正确', () {
      expect(StorageMigrator.isFuture(<String, dynamic>{'schemaVersion': 9}), isTrue);
      expect(StorageMigrator.isFuture(<String, dynamic>{'schemaVersion': 1}), isFalse);
    });

    test('StorageMigrator.warnIfFuture 对高版本告警且不抛', () {
      StorageMigrator.warnIfFuture(<String, dynamic>{'schemaVersion': 9});
      StorageMigrator.warnIfFuture(<String, dynamic>{'schemaVersion': 1});
    });
  });
}
