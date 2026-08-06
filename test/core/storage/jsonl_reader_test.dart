// JSONL 逐行读取器（T15 验收 3）。
//
// 覆盖点：
//  - 解析合法 JSONL，返回全部 items（实际字段名 lines）；
//  - 损坏行跳过并计入 skippedLines，items = 有效条数；
//  - 非 JSON 对象（如数组）行同样计入 skippedLines；
//  - 损坏文件不整体失败（corruptFiles 记录，不抛）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/storage/jsonl_reader.dart';

void main() {
  group('JsonlReader 损坏行跳过并计数（T15 验收 3）', () {
    test('解析合法 JSONL，返回全部 items', () {
      final dir = Directory.systemTemp.createTempSync('jr_ok_');
      final file = File('${dir.path}/ok.jsonl');
      file.writeAsStringSync('{"a":1}\n{"a":2}\n{"a":3}\n');

      final result = const JsonlReader().readFile(file);
      expect(result.lines.length, 3);
      expect(result.skippedLines, 0);
      expect(result.hasCorruption, isFalse);
      dir.deleteSync(recursive: true);
    });

    test('损坏行被跳过并计入 skippedLines，items=有效条数', () {
      final dir = Directory.systemTemp.createTempSync('jr_bad_');
      final file = File('${dir.path}/bad.jsonl');
      file.writeAsStringSync('{"a":1}\nNOT JSON\n{"a":3}\n');

      final result = const JsonlReader().readFile(file);
      expect(result.lines.length, 2);
      expect(result.skippedLines, 1);
      expect(result.hasCorruption, isTrue);
      expect(result.lines.map((m) => m['a']).toList(), <Object>[1, 3]);
      dir.deleteSync(recursive: true);
    });

    test('非 JSON 对象（数组）行计入 skippedLines', () {
      final dir = Directory.systemTemp.createTempSync('jr_arr_');
      final file = File('${dir.path}/arr.jsonl');
      file.writeAsStringSync('[1,2,3]\n{"a":1}\n');

      final result = const JsonlReader().readFile(file);
      expect(result.lines.length, 1);
      expect(result.skippedLines, 1);
      dir.deleteSync(recursive: true);
    });

    test('读不存在文件返回空结果不抛', () {
      final dir = Directory.systemTemp.createTempSync('jr_missing_');
      final file = File('${dir.path}/missing.jsonl');
      final result = const JsonlReader().readFile(file);
      expect(result.lines, isEmpty);
      expect(result.skippedLines, 0);
      dir.deleteSync(recursive: true);
    });
  });
}
