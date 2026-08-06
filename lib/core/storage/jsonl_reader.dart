import 'dart:convert';
import 'dart:io';

import 'package:interval_ear/core/utils/app_logger.dart';

/// 一次 JSONL 读取的结果（T15 验收 3）。
///
/// 损坏行**跳过并计数**，绝不整体失败——训练记录流水里丢一两行旧数据，
/// 远比「因为一行坏数据整个文件读不出来」可接受。
class JsonlReadResult {
  /// 创建读取结果。
  const JsonlReadResult({
    required this.lines,
    this.skippedLines = 0,
    this.corruptFiles = const <String>[],
  });

  /// 成功解析出的 JSON 对象（每行一个）。
  final List<Map<String, dynamic>> lines;

  /// 被跳过的损坏行数。
  final int skippedLines;

  /// 整个文件都读不出来的（非 JSONL 结构、权限等）文件路径。
  final List<String> corruptFiles;

  /// 是否产生了任何需要告警的损坏证据。
  bool get hasCorruption => skippedLines > 0 || corruptFiles.isNotEmpty;
}

/// JSONL 逐行读取器（T15 验收 3）。纯同步解析，便于在测试中确定性调用。
class JsonlReader {
  /// 创建读取器。
  const JsonlReader();

  /// 读取单个文件，损坏行跳过并计数。
  JsonlReadResult readFile(File file) {
    if (!file.existsSync()) {
      return const JsonlReadResult(lines: <Map<String, dynamic>>[]);
    }
    final lines = <Map<String, dynamic>>[];
    var skipped = 0;
    final corruptFiles = <String>[];
    try {
      final content = file.readAsStringSync();
      for (final raw in content.split('\n')) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            lines.add(Map<String, dynamic>.from(decoded));
          } else {
            skipped++;
          }
        } on Object {
          // 单行损坏：跳过并计数，不中断整文件读取。
          skipped++;
        }
      }
    } on Object catch (e) {
      corruptFiles.add(file.path);
      AppLogger.warning(
        'jsonl file unreadable: ${file.path} ($e)',
        tag: 'JsonlReader',
      );
    }
    return JsonlReadResult(
      lines: List<Map<String, dynamic>>.unmodifiable(lines),
      skippedLines: skipped,
      corruptFiles: corruptFiles,
    );
  }

  /// 读取目录中所有 `*.jsonl` 文件并按文件名升序合并。
  ///
  /// 当 [prefix] 非空时，仅保留 basename 以 [prefix] 开头且以 `.jsonl` 结尾的文件，
  /// 以支持同一目录下多族分片（如 `attempts_*.jsonl` 与 `sessions_*.jsonl`）互不串扰
  /// （T16 唯一真相源契约：重建须与增量一致）。[prefix] 为 null 时保持原有
  /// 「读全目录」语义，向后兼容。
  JsonlReadResult readAllInDir(Directory dir, {String? prefix}) {
    if (!dir.existsSync()) {
      return const JsonlReadResult(lines: <Map<String, dynamic>>[]);
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final name = f.uri.pathSegments.last;
          if (!name.endsWith('.jsonl')) {
            return false;
          }
          if (prefix != null && !name.startsWith(prefix)) {
            return false;
          }
          return true;
        })
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final all = <Map<String, dynamic>>[];
    var skipped = 0;
    final corrupt = <String>[];
    for (final file in files) {
      final result = readFile(file);
      all.addAll(result.lines);
      skipped += result.skippedLines;
      corrupt.addAll(result.corruptFiles);
    }
    return JsonlReadResult(
      lines: List<Map<String, dynamic>>.unmodifiable(all),
      skippedLines: skipped,
      corruptFiles: corrupt,
    );
  }
}
