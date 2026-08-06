import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/utils/app_logger.dart';

/// JSON 文件原子读写（T15 验收 1 / 验收 6）。
///
/// **原子写三步**：写临时文件 → `flush`（fsync 落盘）→ `rename`（POSIX 下原子）。
/// 进程在「写完 tmp 但还没 rename」时被 kill，旧文件完好无损；rename 本身是原子的，
/// 不会出现「写了一半的 JSON」。
///
/// **并发写串行化**：同一文件名用一把按名索引的锁串行（验收 6），不同文件互不阻塞。
class JsonFileStore {
  /// 创建一个文件存储（[dir] 必须是已存在的目录）。
  JsonFileStore({required this.dir});

  /// 存储目录。
  final Directory dir;

  /// 文件名 → 等待该文件上一轮写完成的 future（串行化写锁）。
  final Map<String, Future<void>> _writeQueue = <String, Future<void>>{};

  File _fileFor(String name) => File('${dir.path}/$name');

  /// 读取一个 JSON 文件，不存在或非法时返回 `null`（不抛异常）。
  Future<Map<String, dynamic>?> read(String name) async {
    final file = _fileFor(name);
    if (!await file.exists()) {
      return null;
    }
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
    } on Object catch (e, stack) {
      AppLogger.warning(
        'read failed for $name: $e',
        tag: 'JsonFileStore',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// 原子写入 [name]。并发调用同一 [name] 会按调用顺序串行执行。
  Future<void> writeAtomic(String name, Map<String, dynamic> json) async {
    final previous = _writeQueue[name];
    final completer = Completer<void>();
    _writeQueue[name] = completer.future;
    if (previous != null) {
      await previous;
    }
    try {
      await _writeOne(name, json);
    } finally {
      if (identical(_writeQueue[name], completer.future)) {
        _writeQueue.remove(name);
      }
      completer.complete();
    }
  }

  Future<void> _writeOne(String name, Map<String, dynamic> json) async {
    final target = _fileFor(name);
    if (await target.parent.exists() == false) {
      await target.parent.create(recursive: true);
    }
    final tmp = File('${target.path}${AppConfig.tempFileSuffix}');
    final raf = await tmp.open(mode: FileMode.writeOnly);
    try {
      await raf.writeString(jsonEncode(json));
      // fsync：确保字节真正落盘，再执行原子 rename（T15 验收 1）。
      await raf.flush();
    } finally {
      await raf.close();
    }
    // POSIX 下 rename 是原子的；Windows 下先删后移。
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);
  }

  /// 把损坏文件改名备份（追加备份后缀，覆盖旧备份避免无限增长）。
  Future<void> backupCorrupt(String name) async {
    final file = _fileFor(name);
    if (!await file.exists()) {
      return;
    }
    final backup = File('${file.path}${AppConfig.backupFileSuffix}');
    if (await backup.exists()) {
      await backup.delete();
    }
    await file.rename(backup.path);
    AppLogger.warning(
      'corrupt file backed up: ${backup.path}',
      tag: 'JsonFileStore',
    );
  }

  /// 删除一个文件（不存在时静默返回）。
  Future<void> delete(String name) async {
    final file = _fileFor(name);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 列出目录中所有 jsonl 文件名（用于按月分片读取）。
  Future<List<String>> listJsonlNames() async {
    if (!await dir.exists()) {
      return const <String>[];
    }
    final names = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.jsonl')) {
        names.add(entity.uri.pathSegments.last);
      }
    }
    names.sort();
    return names;
  }
}
