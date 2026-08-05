import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// 日志级别，按严重程度递增。
enum LogLevel {
  /// 开发期细节，release 下不输出。
  debug(500, 'DEBUG'),

  /// 关键流程节点。
  info(800, 'INFO'),

  /// 可恢复的异常状况（已降级处理）。
  warning(900, 'WARN'),

  /// 不可恢复的错误。
  error(1000, 'ERROR');

  const LogLevel(this.severity, this.label);

  /// `dart:developer` 的 level 数值。
  final int severity;

  /// 打印用短标签。
  final String label;
}

/// 一条日志记录。测试可以通过 [AppLogger.history] 断言「某个降级动作确实记了日志」。
@immutable
class LogRecord {
  /// 创建一条不可变日志记录。
  const LogRecord({
    required this.level,
    required this.tag,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
  });

  /// 级别。
  final LogLevel level;

  /// 来源标签，通常是类名。
  final String tag;

  /// 消息正文（英文，架构 §8.5 规则 4）。
  final String message;

  /// 记录时刻。
  final DateTime timestamp;

  /// 关联异常对象。
  final Object? error;

  /// 关联堆栈。
  final StackTrace? stackTrace;

  @override
  String toString() => '[${level.label}] $tag: $message';
}

/// 全局分级日志（架构 §8.2：禁止空 `catch`，至少要 `AppLogger`）。
///
/// release 下默认只保留 warning 及以上，避免训练过程中大量 debug 日志拖慢帧率。
abstract final class AppLogger {
  const AppLogger._();

  /// 历史缓冲区容量。超过后丢弃最旧的记录。
  static const int historyCapacity = 200;

  /// 当前最低输出级别。设置页「详细日志」开关会直接改它。
  ///
  /// release 下默认 `warning`，debug 下默认 `debug`。
  static LogLevel minLevel =
      kReleaseMode ? LogLevel.warning : LogLevel.debug;

  static final List<LogRecord> _history = <LogRecord>[];

  /// 额外接收器，供测试或「导出诊断日志」功能挂钩。
  static void Function(LogRecord record)? sink;

  /// 最近的日志记录（只读视图，最旧在前）。
  static List<LogRecord> get history => List<LogRecord>.unmodifiable(_history);

  /// 清空历史缓冲区。测试 `setUp` 中调用，避免用例间互相污染。
  static void clearHistory() => _history.clear();

  /// 输出 debug 级日志。
  static void debug(String message, {String tag = 'app'}) =>
      _log(LogLevel.debug, tag, message, null, null);

  /// 输出 info 级日志。
  static void info(String message, {String tag = 'app'}) =>
      _log(LogLevel.info, tag, message, null, null);

  /// 输出 warning 级日志。
  static void warning(
    String message, {
    String tag = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(LogLevel.warning, tag, message, error, stackTrace);

  /// 输出 error 级日志。
  static void error(
    String message, {
    String tag = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(LogLevel.error, tag, message, error, stackTrace);

  static void _log(
    LogLevel level,
    String tag,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (level.severity < minLevel.severity) {
      return;
    }
    final record = LogRecord(
      level: level,
      tag: tag,
      message: message,
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
    );
    _history.add(record);
    if (_history.length > historyCapacity) {
      _history.removeRange(0, _history.length - historyCapacity);
    }
    sink?.call(record);
    developer.log(
      message,
      name: tag,
      level: level.severity,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
