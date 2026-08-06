import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:interval_ear/core/storage/jsonl_reader.dart';
import 'package:interval_ear/core/utils/app_logger.dart';

/// JSONL 追加器（T15 验收 2 / 验收 4）。
///
/// 每条记录单独刷盘（`flush`）：进程崩溃最多丢**最后一行的尾巴**，前面的行全部可读。
/// 文件名即「分片」([shard])，调用方用 `attempts_YYYY-MM.jsonl` 这种按月分片名保证
/// 跨月自动切换（T16 验收 4）。
class JsonlAppender {
  /// 创建一个追加器（[dir] 为存放 jsonl 的目录）。
  JsonlAppender({required this.dir});

  /// 存放 JSONL 的目录。
  final Directory dir;

  File _fileFor(String shard) => File('${dir.path}/$shard');

  /// 追加一行 JSON（原子一条；自动创建父目录）。
  Future<void> append(String shard, Map<String, dynamic> line) async {
    final file = _fileFor(shard);
    if (await file.parent.exists() == false) {
      await file.parent.create(recursive: true);
    }
    final raf = await file.open(mode: FileMode.append);
    try {
      await raf.writeString('${jsonEncode(line)}\n');
      // 单条 flush：崩溃只可能丢最后一行（T15 验收 2）。
      await raf.flush();
    } finally {
      await raf.close();
    }
  }

  /// 读取某个分片的所有行（委托 [JsonlReader]）。
  JsonlReadResult readShard(String shard) {
    final file = _fileFor(shard);
    return const JsonlReader().readFile(file);
  }

  /// 读取目录下全部分片并合并。
  ///
  /// [prefix] 透传给 [JsonlReader.readAllInDir]：非空时只读取 basename 以 [prefix]
  /// 开头的分片，避免同一目录下 `attempts_*` 与 `sessions_*` 两族分片互相串扰
  /// （T16 唯一真相源契约）。[prefix] 为 null 时行为不变，向后兼容。
  JsonlReadResult readAll({String? prefix}) {
    return const JsonlReader().readAllInDir(dir, prefix: prefix);
  }

  /// 删除所有 jsonl 分片（清空数据用）。
  Future<void> deleteAll() async {
    if (!await dir.exists()) {
      return;
    }
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.jsonl')) {
        try {
          await entity.delete();
        } on Object catch (e, stack) {
          AppLogger.warning(
            'failed to delete ${entity.path}: $e',
            tag: 'JsonlAppender',
            error: e,
            stackTrace: stack,
          );
        }
      }
    }
  }

  /// 追加器每条都已 flush，这里是无操作占位（接口对称）。
  Future<void> flush() async {}
}
