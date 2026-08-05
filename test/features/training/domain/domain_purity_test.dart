// ignore_for_file: prefer_const_constructors
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T04/T05/T06 验收：领域层必须是纯 Dart，**禁止** import `package:flutter/...`。
///
/// 这条规则保证训练算法能在任何 Dart 环境（CLI、后台、测试）里跑，不绑定 UI。
/// 测试直接扫描 `lib/features/training/domain/` 下所有 .dart 文件，逐行检查。
void main() {
  final domainRoot = '${Directory.current.path}/lib/features/training/domain';

  Iterable<File> collectDartFiles(Directory dir) sync* {
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        yield entity;
      }
    }
  }

  test('领域层不含任何 flutter import', () {
    final dir = Directory(domainRoot);
    expect(dir.existsSync(), isTrue,
        reason: '领域层目录应当存在：$domainRoot');
    final files = collectDartFiles(dir).toList();
    expect(files, isNotEmpty);

    final violators = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (final line in lines) {
        if (line.trim().startsWith("import 'package:flutter")) {
          violators.add('${file.path}: $line');
        }
      }
    }
    expect(violators, isEmpty,
        reason: '以下文件错误地引用了 flutter:\n${violators.join('\n')}');
  });

  test('领域层不引用 any 表现层代码', () {
    final dir = Directory(domainRoot);
    final forbidden = <String>[
      "import 'package:flutter",
      "import 'package:interval_ear/app",
      "import 'package:interval_ear/features/player",
    ];
    final violators = <String>[];
    for (final file in collectDartFiles(dir)) {
      for (final line in file.readAsLinesSync()) {
        for (final prefix in forbidden) {
          if (line.trim().startsWith(prefix)) {
            violators.add('${file.path}: $line');
          }
        }
      }
    }
    expect(violators, isEmpty,
        reason: '领域层不应依赖表现层：\n${violators.join('\n')}');
  });
}
