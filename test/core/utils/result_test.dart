import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/utils/failures.dart';
import 'package:interval_ear/core/utils/result.dart';

/// T01 验收项：`Result` / `AppFailure` 必须有单测覆盖。
void main() {
  const StorageFailure storageFailure = StorageFailure(
    kind: StorageFailureKind.readFailed,
    message: 'read failed',
    path: '/tmp/db.sqlite',
  );

  group('Result 基础判别', () {
    test('Ok 判别与取值', () {
      const Result<int> r = Ok<int>(7);
      expect(r.isOk, isTrue);
      expect(r.isErr, isFalse);
      expect(r.valueOrNull, 7);
      expect(r.failureOrNull, isNull);
    });

    test('Err 判别与取值', () {
      const Result<int> r = Err<int>(storageFailure);
      expect(r.isOk, isFalse);
      expect(r.isErr, isTrue);
      expect(r.valueOrNull, isNull);
      expect(r.failureOrNull, same(storageFailure));
    });

    test('工厂构造函数等价于直接构造', () {
      expect(Result<int>.ok(3), const Ok<int>(3));
      expect(
        Result<int>.err(storageFailure),
        const Err<int>(storageFailure),
      );
    });

    test('Ok(null) 与 Err 可区分（valueOrNull 不足以判别）', () {
      const Result<int?> ok = Ok<int?>(null);
      expect(ok.isOk, isTrue);
      expect(ok.valueOrNull, isNull);
      expect(ok.failureOrNull, isNull);
    });
  });

  group('Result 组合子', () {
    test('fold 走对应分支', () {
      const Result<int> ok = Ok<int>(2);
      const Result<int> err = Err<int>(storageFailure);
      expect(
        ok.fold((int v) => 'ok:$v', (AppFailure f) => 'err'),
        'ok:2',
      );
      expect(
        err.fold(
          (int v) => 'ok:$v',
          (AppFailure f) => 'err:${f.code}',
        ),
        'err:storage.readFailed',
      );
    });

    test('map 只作用于 Ok，Err 原样透传', () {
      expect(const Ok<int>(4).map<String>((int v) => 'v$v'), const Ok<String>('v4'));
      final Result<String> mapped =
          const Err<int>(storageFailure).map<String>((int v) => 'never');
      expect(mapped.isErr, isTrue);
      expect(mapped.failureOrNull, same(storageFailure));
    });

    test('mapErr 只作用于 Err，Ok 原样透传', () {
      const AppFailure replaced = ValidationFailure(message: 'bad', field: 'n');
      final Result<int> r = const Err<int>(storageFailure)
          .mapErr((AppFailure f) => replaced);
      expect(r.failureOrNull, same(replaced));
      expect(const Ok<int>(1).mapErr((AppFailure f) => replaced), const Ok<int>(1));
    });

    test('flatMap 串联并在首个 Err 处短路', () {
      Result<int> half(int v) => v.isEven
          ? Ok<int>(v ~/ 2)
          : const Err<int>(ValidationFailure(message: 'odd', field: 'v'));

      expect(const Ok<int>(8).flatMap(half).flatMap(half), const Ok<int>(2));

      final Result<int> shortCircuit =
          const Ok<int>(6).flatMap(half).flatMap(half);
      expect(shortCircuit.isErr, isTrue);
      expect(shortCircuit.failureOrNull!.code, 'validation.v');
    });

    test('getOrElse / getOrDefault', () {
      expect(const Ok<int>(5).getOrElse((AppFailure f) => -1), 5);
      expect(const Err<int>(storageFailure).getOrElse((AppFailure f) => -1), -1);
      expect(const Ok<int>(5).getOrDefault(0), 5);
      expect(const Err<int>(storageFailure).getOrDefault(0), 0);
    });

    test('sealed 类支持穷尽 switch（编译期保证）', () {
      String describe(Result<int> r) => switch (r) {
            final Ok<int> ok => 'ok:${ok.value}',
            final Err<int> err => 'err:${err.failure.code}',
          };
      expect(describe(const Ok<int>(1)), 'ok:1');
      expect(describe(const Err<int>(storageFailure)), 'err:storage.readFailed');
    });
  });

  group('Result 相等性', () {
    test('值相等则实例相等', () {
      expect(const Ok<int>(1), const Ok<int>(1));
      expect(const Ok<int>(1).hashCode, const Ok<int>(1).hashCode);
      expect(const Ok<int>(1), isNot(const Ok<int>(2)));
    });

    test('不同泛型的 Ok 不相等', () {
      expect(const Ok<int>(1) == const Ok<num>(1), isFalse);
    });

    test('Err 与 Ok 不相等', () {
      const Result<int> ok = Ok<int>(1);
      const Result<int> err = Err<int>(storageFailure);
      expect(ok == err, isFalse);
    });

    test('toString 可读', () {
      expect(const Ok<int>(1).toString(), 'Ok<int>(1)');
      expect(
        const Err<int>(storageFailure).toString(),
        contains('storage.readFailed'),
      );
    });
  });

  group('AppFailure 错误码', () {
    test('StorageFailure code 带 kind 后缀', () {
      for (final StorageFailureKind kind in StorageFailureKind.values) {
        final StorageFailure f = StorageFailure(kind: kind, message: 'm');
        expect(f.code, 'storage.${kind.name}');
        expect(f.path, '');
      }
    });

    test('AudioFailure code 带 kind 后缀', () {
      for (final AudioFailureKind kind in AudioFailureKind.values) {
        expect(
          AudioFailure(kind: kind, message: 'm').code,
          'audio.${kind.name}',
        );
      }
    });

    test('AudioFailure.isFatal 只对初始化/引擎不可用为真', () {
      for (final AudioFailureKind kind in AudioFailureKind.values) {
        final bool expected = kind == AudioFailureKind.initializationFailed ||
            kind == AudioFailureKind.engineUnavailable;
        expect(
          AudioFailure(kind: kind, message: 'm').isFatal,
          expected,
          reason: 'kind=$kind',
        );
      }
    });

    test('ValidationFailure code 随 field 变化', () {
      expect(const ValidationFailure(message: 'm').code, 'validation');
      expect(
        const ValidationFailure(message: 'm', field: 'questionCount').code,
        'validation.questionCount',
      );
    });

    test('UnknownFailure code 固定', () {
      expect(const UnknownFailure(message: 'boom').code, 'unknown');
    });

    test('toString 含 code、message，有 cause 时附带 cause', () {
      const AppFailure noCause = UnknownFailure(message: 'boom');
      expect(noCause.toString(), 'unknown: boom');

      final AppFailure withCause = UnknownFailure(
        message: 'boom',
        cause: StateError('inner'),
      );
      expect(withCause.toString(), contains('cause:'));
      expect(withCause.toString(), contains('inner'));
    });

    test('failure 可以承载 stackTrace 且不影响 code', () {
      final StackTrace st = StackTrace.current;
      final AppFailure f = StorageFailure(
        kind: StorageFailureKind.writeFailed,
        message: 'm',
        stackTrace: st,
      );
      expect(f.stackTrace, same(st));
      expect(f.code, 'storage.writeFailed');
    });

    test('AppFailure 支持穷尽 switch', () {
      String tag(AppFailure f) => switch (f) {
            StorageFailure() => 'storage',
            AudioFailure() => 'audio',
            ValidationFailure() => 'validation',
            UnknownFailure() => 'unknown',
          };
      expect(tag(storageFailure), 'storage');
      expect(
        tag(const AudioFailure(kind: AudioFailureKind.engineUnavailable, message: 'm')),
        'audio',
      );
      expect(tag(const ValidationFailure(message: 'm')), 'validation');
      expect(tag(const UnknownFailure(message: 'm')), 'unknown');
    });
  });
}
