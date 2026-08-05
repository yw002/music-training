import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/cache/lru_map.dart';

/// T08 验收 4：定容 LRU 淘汰顺序。
void main() {
  group('LruMap 定容淘汰', () {
    test('超出容量时淘汰最久未使用（队首）', () {
      final LruMap<String, int> map = LruMap<String, int>(2);
      map['a'] = 1;
      map['b'] = 2;
      map['c'] = 3; // 触发淘汰 a。
      expect(map.containsKey('a'), isFalse);
      expect(map['b'], 2);
      expect(map['c'], 3);
      expect(map.length, 2);
    });

    test('访问已存在键会把它标记为最近使用，改变淘汰顺序', () {
      final LruMap<String, int> map = LruMap<String, int>(2);
      map['a'] = 1;
      map['b'] = 2;
      map['a']; // 访问 a → a 变为最近使用。
      map['c'] = 3; // 淘汰最久未用的 b。
      expect(map.containsKey('b'), isFalse);
      expect(map['a'], 1);
      expect(map['c'], 3);
    });

    test('更新已存在键不新增条目、并标记为最近使用', () {
      final LruMap<String, int> map = LruMap<String, int>(2);
      map['a'] = 1;
      map['b'] = 2;
      map['a'] = 10; // 更新，非新增。
      expect(map.length, 2);
      expect(map['a'], 10);
      map['c'] = 3; // 淘汰 b。
      expect(map.containsKey('b'), isFalse);
    });

    test('keys 顺序从老到新', () {
      final LruMap<String, int> map = LruMap<String, int>(3);
      map['a'] = 1;
      map['b'] = 2;
      map['c'] = 3;
      expect(map.keys.toList(), <String>['a', 'b', 'c']);
      map['a']; // a 变最近。
      map['d'] = 4; // 淘汰 b。
      expect(map.keys.toList(), <String>['c', 'a', 'd']);
    });

    test('容量必须为正（构造断言）', () {
      expect(() => LruMap<String, int>(0), throwsAssertionError);
    });

    test('clear 清空全部', () {
      final LruMap<String, int> map = LruMap<String, int>(2);
      map['a'] = 1;
      map['b'] = 2;
      map.clear();
      expect(map.isEmpty, isTrue);
      expect(map.length, 0);
    });
  });
}
