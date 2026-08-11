import 'dart:collection';

/// 固定容量的 LRU（最近最少使用）映射（T08 验收 4）。
///
/// 用 [LinkedHashMap] 维护插入顺序：`get` 命中时把键移到末尾（标记最近使用），
/// 超额 `put` 时淘汰队首（最久未用）。所有操作 O(1)。
///
/// 之所以自己实现而不是用 `package:collection` 的 `LruMap`：需要精确控制淘汰语义
/// 并暴露 [length] / [keys] 供单测断言，且避免额外依赖。
class LruMap<K, V> {
  /// 创建一个容量上限为 [capacity] 的 LRU 映射。
  LruMap(this.capacity, {this.onEvicted}) : assert(capacity > 0, '容量必须为正');

  /// 容量上限（淘汰触发线）。
  final int capacity;

  /// 条目因超容量或清空被移除时的释放回调。
  final void Function(V value)? onEvicted;

  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  /// 当前条目数。
  int get length => _map.length;

  /// 是否空。
  bool get isEmpty => _map.isEmpty;

  /// 是否满。
  bool get isNotEmpty => _map.isNotEmpty;

  /// 全部键（按最近使用从老到新）。
  Iterable<K> get keys => _map.keys;

  /// 全部值（按最近使用从老到新）。
  Iterable<V> get values => _map.values;

  /// 取值；命中则标记为最近使用，未命中返回 `null`。
  V? operator [](K key) {
    final V? value = _map[key];
    if (value == null) {
      return null;
    }
    // 移到末尾：删除后重新插入即放到队尾（最近使用）。
    _map.remove(key);
    _map[key] = value;
    return value;
  }

  /// 写入；若已存在则更新并标记为最近使用；超额则淘汰最久未用者。
  void operator []=(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    }
    _map[key] = value;
    if (_map.length > capacity) {
      final K oldest = _map.keys.first;
      final V? removed = _map.remove(oldest);
      if (removed != null) {
        onEvicted?.call(removed);
      }
    }
  }

  /// 是否包含键。
  bool containsKey(K key) => _map.containsKey(key);

  /// 清空。
  void clear({bool notifyEvicted = true}) {
    if (notifyEvicted && onEvicted != null) {
      for (final V value in _map.values) {
        onEvicted!(value);
      }
    }
    _map.clear();
  }
}
