// JSON 文件原子读写（T15 验收 1 / 验收 6）。
//
// 覆盖点：
//  - 原子写三步 tmp→fsync→rename：写后字节等于输入，且无残留 .tmp 文件；
//  - 读损坏 / 不存在文件返回 null 不抛；
//  - 并发写同一文件串行化，最终内容完整且为最后一次写入（无半截 JSON）。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/storage/json_file_store.dart';

void main() {
  group('JsonFileStore 原子写（T15 验收 1 / 验收 6）', () {
    late Directory dir;
    late JsonFileStore store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('jfs_test_');
      store = JsonFileStore(dir: dir);
    });

    tearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('writeAtomic 写后字节等于输入，且无残留临时文件', () async {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'hello': 'world',
        'n': 42,
      };
      await store.writeAtomic('a.json', json);

      final file = File('${dir.path}/a.json');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, jsonEncode(json));

      // 临时文件后缀来自 AppConfig，写完后必须不存在。
      final tmpFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith(AppConfig.tempFileSuffix))
          .toList();
      expect(tmpFiles, isEmpty);
    });

    test('并发写同一文件串行化，最终内容完整且为最后一次写入', () async {
      final futures = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        futures.add(store.writeAtomic('concurrent.json', <String, dynamic>{'i': i}));
      }
      await Future.wait(futures);

      final content = File('${dir.path}/concurrent.json').readAsStringSync();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      // 串行化保证最后一次写入胜出，且整段 JSON 完整可解析。
      expect(decoded['i'], 20 - 1);
      expect(jsonDecode(content), isA<Map<String, dynamic>>());
    });

    test('read 读到不存在 / 损坏文件返回 null 不抛', () async {
      expect(await store.read('nope.json'), isNull);

      final broken = File('${dir.path}/broken.json');
      broken.writeAsStringSync('{ this is not valid json');
      expect(await store.read('broken.json'), isNull);
    });

    test('listJsonlNames 仅返回按文件名升序的 jsonl 文件', () async {
      await store.writeAtomic('attempts_2026-02.jsonl', <String, dynamic>{});
      await store.writeAtomic('attempts_2026-01.jsonl', <String, dynamic>{});
      await store.writeAtomic('stats.json', <String, dynamic>{});

      final names = await store.listJsonlNames();
      expect(names, <String>['attempts_2026-01.jsonl', 'attempts_2026-02.jsonl']);
    });
  });
}
