// JSONL 追加器（T15 验收 2 / 验收 4）。
//
// 覆盖点：
//  - 每次 append 写一条完整 JSON 行 + 换行；
//  - 追加 N 行后读回 N 条有效记录；
//  - 最后一行被截断（进程崩溃场景）：只丢那一行，前面的行全部可读，且损坏行被计数。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/storage/jsonl_appender.dart';

void main() {
  group('JsonlAppender 单条完整 + 崩溃只丢最后一行（T15 验收 2）', () {
    late Directory dir;
    late JsonlAppender appender;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('ja_test_');
      appender = JsonlAppender(dir: dir);
    });

    tearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('追加 N 行，读回 N 条有效记录，每行独立 flush', () async {
      const int n = 5;
      for (var i = 0; i < n; i++) {
        await appender.append(
          'attempts_2026-01.jsonl',
          <String, dynamic>{'i': i, 'type': 'attempt'},
        );
      }

      final result = appender.readShard('attempts_2026-01.jsonl');
      expect(result.lines.length, n);
      expect(result.skippedLines, 0);
      expect(result.lines.last['i'], n - 1);
    });

    test('最后一行被截断：读回有效行，损坏行计入 skippedLines', () async {
      for (var i = 0; i < 3; i++) {
        await appender.append(
          'a.jsonl',
          <String, dynamic>{'i': i},
        );
      }

      // 模拟崩溃：截断最后一个 JSON（去掉末尾若干字节，使其变成非法但非空的行）。
      final file = File('${dir.path}/a.jsonl');
      final bytes = file.readAsBytesSync();
      file.writeAsBytesSync(bytes.sublist(0, bytes.length - 6));

      final result = appender.readAll();
      // 前 2 行完好可读，被截断的最后 1 行被跳过并计数。
      expect(result.lines.length, 2);
      expect(result.skippedLines, 1);
      expect(result.hasCorruption, isTrue);
    });

    test('按月分片：不同月份落到不同文件', () async {
      final jan = DateTime.utc(2026, 1, 15);
      final feb = DateTime.utc(2026, 2, 15);
      await appender.append(
        'attempts_2026-01.jsonl',
        <String, dynamic>{'t': jan.toIso8601String()},
      );
      await appender.append(
        'attempts_2026-02.jsonl',
        <String, dynamic>{'t': feb.toIso8601String()},
      );

      final janFile = File('${dir.path}/attempts_2026-01.jsonl');
      final febFile = File('${dir.path}/attempts_2026-02.jsonl');
      expect(janFile.existsSync(), isTrue);
      expect(febFile.existsSync(), isTrue);
      expect(appender.readShard('attempts_2026-01.jsonl').lines.length, 1);
      expect(appender.readShard('attempts_2026-02.jsonl').lines.length, 1);
    });
  });
}
