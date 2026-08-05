import 'dart:math' as math;

/// 通用集合扩展。
///
/// 只补 `collection` 包中本项目真正用到的那几个方法，避免为 4 个函数引入一个
/// 额外依赖（依赖清单 §7.3 的取舍原则）。
extension IterableExtensions<E> on Iterable<E> {
  /// 返回第一个满足 [test] 的元素，没有则返回 `null`。
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }

  /// 返回最后一个满足 [test] 的元素，没有则返回 `null`。
  E? lastWhereOrNull(bool Function(E element) test) {
    E? found;
    for (final element in this) {
      if (test(element)) {
        found = element;
      }
    }
    return found;
  }

  /// 对每个元素取 [selector] 的结果求和。空集合返回 0。
  double sumBy(num Function(E element) selector) {
    var total = 0.0;
    for (final element in this) {
      total += selector(element);
    }
    return total;
  }

  /// 对每个元素取 [selector] 的结果求整数和。空集合返回 0。
  int sumIntBy(int Function(E element) selector) {
    var total = 0;
    for (final element in this) {
      total += selector(element);
    }
    return total;
  }

  /// 按 [keyOf] 分组。保持插入顺序（`LinkedHashMap` 语义），便于渲染结果稳定。
  Map<K, List<E>> groupBy<K>(K Function(E element) keyOf) {
    final result = <K, List<E>>{};
    for (final element in this) {
      result.putIfAbsent(keyOf(element), () => <E>[]).add(element);
    }
    return result;
  }

  /// 用注入的随机源做 Fisher–Yates 洗牌，返回新列表，不修改原集合。
  ///
  /// 架构 §8.7 要求「一律注入 `Xorshift32Random(seed)`」，因此这里强制传 [random]，
  /// 不提供默认的 `Random()` 重载。
  List<E> shuffledWith(math.Random random) {
    final items = List<E>.of(this);
    for (var i = items.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
    return items;
  }

  /// 返回 [selector] 值最大的元素，空集合返回 `null`。
  E? maxByOrNull(num Function(E element) selector) {
    E? best;
    num? bestValue;
    for (final element in this) {
      final value = selector(element);
      if (bestValue == null || value > bestValue) {
        bestValue = value;
        best = element;
      }
    }
    return best;
  }

  /// 返回 [selector] 值最小的元素，空集合返回 `null`。
  E? minByOrNull(num Function(E element) selector) {
    E? best;
    num? bestValue;
    for (final element in this) {
      final value = selector(element);
      if (bestValue == null || value < bestValue) {
        bestValue = value;
        best = element;
      }
    }
    return best;
  }

  /// 带下标的 map。
  Iterable<R> mapIndexed<R>(R Function(int index, E element) transform) sync* {
    var index = 0;
    for (final element in this) {
      yield transform(index, element);
      index++;
    }
  }

  /// 取前 [count] 个元素组成列表，[count] 超过长度时返回全部。
  List<E> takeAtMost(int count) {
    if (count <= 0) {
      return <E>[];
    }
    return take(count).toList(growable: false);
  }
}

/// 列表专用扩展。
extension ListExtensions<E> on List<E> {
  /// 下标越界时返回 `null`，避免到处写 `index < list.length ? ... : null`。
  E? elementAtOrNull(int index) =>
      index >= 0 && index < length ? this[index] : null;
}
