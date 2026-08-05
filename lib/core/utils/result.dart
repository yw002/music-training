import 'package:interval_ear/core/utils/failures.dart';

/// 数据层统一返回类型（架构 §8.2）。
///
/// 为什么不用 `throw`：数据层的失败是**预期内**的（文件不存在、音频引擎不可用），
/// 用异常做流程控制会让调用方无法从类型上看出「这里会失败」。`Result` 把失败
/// 提升到类型系统里，配合 `sealed` 让 `switch` 被编译器强制穷尽。
sealed class Result<T> {
  const Result();

  /// 成功构造的语法糖。
  factory Result.ok(T value) = Ok<T>;

  /// 失败构造的语法糖。
  factory Result.err(AppFailure failure) = Err<T>;

  /// 是否成功。
  bool get isOk => this is Ok<T>;

  /// 是否失败。
  bool get isErr => this is Err<T>;

  /// 成功时返回值，失败时返回 `null`。
  T? get valueOrNull => switch (this) {
        final Ok<T> ok => ok.value,
        Err<T>() => null,
      };

  /// 失败时返回失败对象，成功时返回 `null`。
  AppFailure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        final Err<T> err => err.failure,
      };

  /// 双分支归约：把 `Result` 折叠成一个具体值。
  R fold<R>(R Function(T value) onOk, R Function(AppFailure failure) onErr) =>
      switch (this) {
        final Ok<T> ok => onOk(ok.value),
        final Err<T> err => onErr(err.failure),
      };

  /// 成功时变换值，失败时原样透传失败。
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        final Ok<T> ok => Ok<R>(transform(ok.value)),
        final Err<T> err => Err<R>(err.failure),
      };

  /// 失败时变换失败对象，成功时原样透传值。
  Result<T> mapErr(AppFailure Function(AppFailure failure) transform) =>
      switch (this) {
        final Ok<T> ok => Ok<T>(ok.value),
        final Err<T> err => Err<T>(transform(err.failure)),
      };

  /// 链式组合：成功时继续执行下一个可能失败的操作。
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
        final Ok<T> ok => transform(ok.value),
        final Err<T> err => Err<R>(err.failure),
      };

  /// 失败时用回调计算兜底值。降级读取默认配置的标准写法。
  T getOrElse(T Function(AppFailure failure) orElse) => switch (this) {
        final Ok<T> ok => ok.value,
        final Err<T> err => orElse(err.failure),
      };

  /// 失败时直接返回常量兜底值。
  T getOrDefault(T fallback) => switch (this) {
        final Ok<T> ok => ok.value,
        Err<T>() => fallback,
      };

  /// 成功时执行副作用（记日志、打点），返回自身以便链式调用。
  Result<T> onOk(void Function(T value) action) {
    if (this case final Ok<T> ok) {
      action(ok.value);
    }
    return this;
  }

  /// 失败时执行副作用，返回自身以便链式调用。
  Result<T> onErr(void Function(AppFailure failure) action) {
    if (this case final Err<T> err) {
      action(err.failure);
    }
    return this;
  }
}

/// 成功分支。
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  /// 成功携带的值。
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T> && other.value == value);

  @override
  int get hashCode => Object.hash(Ok<T>, value);

  @override
  String toString() => 'Ok<$T>($value)';
}

/// 失败分支。泛型参数 `T` 保留「本应返回什么类型」的信息，便于类型推断。
final class Err<T> extends Result<T> {
  const Err(this.failure);

  /// 失败详情。
  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T> && other.failure == failure);

  @override
  int get hashCode => Object.hash(Err<T>, failure);

  @override
  String toString() => 'Err<$T>($failure)';
}
