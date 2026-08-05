/// 应用级失败类型（架构 §8.2）。
///
/// 为什么用 `sealed class` 而不是 `enum`：失败需要携带上下文（原始异常、路径、
/// 字段名），`enum` 无法承载；`sealed` 又能让调用方在 `switch` 中被编译器强制穷尽。
library;

/// 存储失败的细分原因。
///
/// 之所以在 `core/utils` 而不是 `core/storage` 定义：`Result`/`AppFailure` 是
/// 全项目最底层的契约，不能反向依赖上层模块，否则会形成循环依赖。
enum StorageFailureKind {
  /// 文件或目录不存在。
  notFound,

  /// 权限不足 / 只读文件系统。
  permissionDenied,

  /// 磁盘写入失败（空间不足、IO 错误）。
  writeFailed,

  /// 磁盘读取失败。
  readFailed,

  /// 内容存在但无法解析（JSON 语法错误、字段类型不符）。
  corrupted,

  /// schemaVersion 高于当前程序支持的版本，无法向下兼容。
  unsupportedSchemaVersion,
}

/// 音频失败的细分原因。
enum AudioFailureKind {
  /// 后端初始化失败（设备被占用、驱动缺失）。
  initializationFailed,

  /// 音频引擎不可用，需全局降级到 `FakeAudioService`。
  engineUnavailable,

  /// PCM 合成过程出错。
  synthesisFailed,

  /// 单次播放失败（可重试，不阻塞训练）。
  playbackFailed,
}

/// 所有预期内失败的基类。数据层返回 `Err(AppFailure)`，表现层消费后转成 UI 状态。
sealed class AppFailure {
  const AppFailure({
    required this.message,
    this.cause,
    this.stackTrace,
  });

  /// 面向开发者的英文描述（架构 §8.5 规则 4：日志与异常消息不进 `AppStrings`）。
  final String message;

  /// 触发本次失败的原始异常对象，可为空。
  final Object? cause;

  /// 原始堆栈，仅用于日志，不展示给用户。
  final StackTrace? stackTrace;

  /// 稳定的机器可读错误码，用于日志聚合与测试断言。
  String get code;

  @override
  String toString() => '$code: $message${cause == null ? '' : ' (cause: $cause)'}';
}

/// 存储层失败。
final class StorageFailure extends AppFailure {
  const StorageFailure({
    required this.kind,
    required super.message,
    this.path = '',
    super.cause,
    super.stackTrace,
  });

  /// 细分原因。
  final StorageFailureKind kind;

  /// 相关文件路径，未知时为空串（避免 nullable 传染）。
  final String path;

  @override
  String get code => 'storage.${kind.name}';
}

/// 音频层失败。
final class AudioFailure extends AppFailure {
  const AudioFailure({
    required this.kind,
    required super.message,
    super.cause,
    super.stackTrace,
  });

  /// 细分原因。
  final AudioFailureKind kind;

  /// 该失败是否应触发全局降级（切换到 `FakeAudioService` + 常驻 banner）。
  bool get isFatal =>
      kind == AudioFailureKind.initializationFailed ||
      kind == AudioFailureKind.engineUnavailable;

  @override
  String get code => 'audio.${kind.name}';
}

/// 入参校验失败（配置非法、题数越界等）。
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.message,
    this.field = '',
    super.cause,
    super.stackTrace,
  });

  /// 出错字段名，未知时为空串。
  final String field;

  @override
  String get code => field.isEmpty ? 'validation' : 'validation.$field';
}

/// 兜底失败：`runZonedGuarded` 捕获到的未分类异常。
final class UnknownFailure extends AppFailure {
  const UnknownFailure({
    required super.message,
    super.cause,
    super.stackTrace,
  });

  @override
  String get code => 'unknown';
}
