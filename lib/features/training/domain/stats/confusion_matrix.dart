import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/domain/stats/confusion_entry.dart';

/// 混淆矩阵：`actual → selected → count`（原规范硬性要求的结构）。
///
/// **稀疏存储**：13×13 = 169 格里绝大多数是 0，用嵌套 `Map` 只存非零项，
/// JSON 里 `count == 0` 一律不落盘。
///
/// **两条容易写错的业务规则**：
/// 1. 对角线（`actual == selected`，即答对）**要记录**——报告页要用 success 色系
///    画对角线，没有对角线就无法呈现「哪些音程稳」。
/// 2. `isUncertain == true` 的作答**不进矩阵**。原规范原文：「不确定不能算作
///    普通错误猜测」。若把它当成一次错选记进去，会凭空制造出并不存在的混淆对，
///    进而把弱项训练引到错误方向。
///
/// 本类**可变**（`increment` 原地修改），因为热路径上每答一题就要更新一次，
/// 走不可变拷贝会在长会话里产生大量垃圾。因此它不继承 `Equatable`，
/// `==` 手写深比较（JSON 往返测试需要）。
class ConfusionMatrix {
  /// 创建一个矩阵。传入的 [counts] 会被深拷贝，调用方之后修改原 Map 不会影响本对象。
  ConfusionMatrix([Map<IntervalId, Map<IntervalId, int>>? counts])
      : _counts = <IntervalId, Map<IntervalId, int>>{} {
    if (counts != null) {
      for (final row in counts.entries) {
        for (final cell in row.value.entries) {
          if (cell.value > 0) {
            _counts
                .putIfAbsent(row.key, () => <IntervalId, int>{})[cell.key] =
                cell.value;
          }
        }
      }
    }
  }

  /// 空矩阵。
  factory ConfusionMatrix.empty() => ConfusionMatrix();

  final Map<IntervalId, Map<IntervalId, int>> _counts;

  /// 是否没有任何记录。
  bool get isEmpty => _counts.isEmpty;

  /// 全部非零格的总次数。
  int get totalCount {
    var sum = 0;
    for (final row in _counts.values) {
      for (final value in row.values) {
        sum += value;
      }
    }
    return sum;
  }

  /// 记一次「实际 [actual]，选了 [selected]」。
  void increment(IntervalId actual, IntervalId selected, {int by = 1}) {
    if (by <= 0) {
      return;
    }
    final row = _counts.putIfAbsent(actual, () => <IntervalId, int>{});
    row[selected] = (row[selected] ?? 0) + by;
  }

  /// 按业务规则吸收一条作答：只有「非不确定且有明确选择」的才进矩阵。
  ///
  /// 返回是否真的记了一笔，便于调用方断言过滤逻辑。
  bool absorb(TrainingAttempt attempt) {
    if (!attempt.countsTowardConfusion) {
      return false;
    }
    increment(attempt.correctInterval, attempt.selectedInterval!);
    return true;
  }

  /// 取某一格的次数，缺失为 0。
  int countOf(IntervalId actual, IntervalId selected) =>
      _counts[actual]?[selected] ?? 0;

  /// 某一行（某个正确音程）的总次数。
  int rowTotal(IntervalId actual) {
    final row = _counts[actual];
    if (row == null) {
      return 0;
    }
    var sum = 0;
    for (final value in row.values) {
      sum += value;
    }
    return sum;
  }

  /// 某一列（用户选了该音程）的总次数。
  int columnTotal(IntervalId selected) {
    var sum = 0;
    for (final row in _counts.values) {
      sum += row[selected] ?? 0;
    }
    return sum;
  }

  /// 全矩阵最大格值，空矩阵返回 0。热力图归一化用。
  int maxCount() {
    var maxValue = 0;
    for (final row in _counts.values) {
      for (final value in row.values) {
        if (value > maxValue) {
          maxValue = value;
        }
      }
    }
    return maxValue;
  }

  /// 全部非零格，按 [_compareEntries] 排序。
  List<ConfusionEntry> allEntries({bool includeDiagonal = true}) {
    final entries = <ConfusionEntry>[];
    for (final row in _counts.entries) {
      for (final cell in row.value.entries) {
        if (cell.value <= 0) {
          continue;
        }
        if (!includeDiagonal && row.key == cell.key) {
          continue;
        }
        entries.add(
          ConfusionEntry(
            actual: row.key,
            selected: cell.key,
            count: cell.value,
          ),
        );
      }
    }
    entries.sort(_compareEntries);
    return List<ConfusionEntry>.unmodifiable(entries);
  }

  /// 次数最多的前 [k] 格。默认**排除对角线**——「答对最多的音程」不是混淆信息。
  List<ConfusionEntry> topEntries(int k, {bool includeDiagonal = false}) {
    if (k <= 0) {
      return const <ConfusionEntry>[];
    }
    final entries = allEntries(includeDiagonal: includeDiagonal);
    return List<ConfusionEntry>.unmodifiable(
      entries.length <= k ? entries : entries.sublist(0, k),
    );
  }

  /// 某个正确音程最容易被误选成哪些音程（不含对角线），按排序规则取前 [limit] 个。
  List<ConfusionEntry> rowEntries(IntervalId actual, {int limit = 0}) {
    final row = _counts[actual];
    if (row == null) {
      return const <ConfusionEntry>[];
    }
    final entries = <ConfusionEntry>[];
    for (final cell in row.entries) {
      if (cell.key == actual || cell.value <= 0) {
        continue;
      }
      entries.add(
        ConfusionEntry(actual: actual, selected: cell.key, count: cell.value),
      );
    }
    entries.sort(_compareEntries);
    if (limit > 0 && entries.length > limit) {
      return List<ConfusionEntry>.unmodifiable(entries.sublist(0, limit));
    }
    return List<ConfusionEntry>.unmodifiable(entries);
  }

  /// 混淆最严重的前 [k] 组音程对。
  ///
  /// 与 [topEntries] 的区别：这里把 `(M6→m6)` 与 `(m6→M6)` **合并**成同一对再排序，
  /// 因为二选一强化训练针对的是「一对音程」，方向无关。
  List<IntervalPair> topPairs(int k) {
    if (k <= 0) {
      return const <IntervalPair>[];
    }
    final merged = <String, int>{};
    final pairByKey = <String, IntervalPair>{};
    for (final entry in allEntries(includeDiagonal: false)) {
      final pair = entry.toPair();
      final key = pair.key();
      merged[key] = (merged[key] ?? 0) + entry.count;
      pairByKey[key] = pair;
    }
    final keys = merged.keys.toList()
      ..sort((a, b) {
        final byCount = merged[b]!.compareTo(merged[a]!);
        if (byCount != 0) {
          return byCount;
        }
        final pa = pairByKey[a]!;
        final pb = pairByKey[b]!;
        final byDistance =
            pa.semitoneDistance.compareTo(pb.semitoneDistance);
        if (byDistance != 0) {
          return byDistance;
        }
        return a.compareTo(b);
      });
    final result = <IntervalPair>[];
    for (final key in keys) {
      if (result.length >= k) {
        break;
      }
      result.add(pairByKey[key]!);
    }
    return List<IntervalPair>.unmodifiable(result);
  }

  /// 深拷贝。`StatsSnapshot` 做不可变更新时用。
  ConfusionMatrix copy() => ConfusionMatrix(_counts);

  /// 只读视图，供测试与报告页遍历。
  Map<IntervalId, Map<IntervalId, int>> toMap() =>
      Map<IntervalId, Map<IntervalId, int>>.unmodifiable(<IntervalId,
          Map<IntervalId, int>>{
        for (final row in _counts.entries)
          row.key: Map<IntervalId, int>.unmodifiable(row.value),
      });

  /// 排序规则：次数降序 → 半音距离升序 → 正确音程半音数升序 → 所选音程半音数升序。
  ///
  /// 后两级只是为了让结果**完全确定**（同分时不能依赖 Map 的遍历顺序），
  /// 否则同一份数据在不同运行里排出的报告会不一样。
  static int _compareEntries(ConfusionEntry a, ConfusionEntry b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) {
      return byCount;
    }
    final byDistance = a.semitoneDistance.compareTo(b.semitoneDistance);
    if (byDistance != 0) {
      return byDistance;
    }
    final byActual = a.actual.semitones.compareTo(b.actual.semitones);
    if (byActual != 0) {
      return byActual;
    }
    return a.selected.semitones.compareTo(b.selected.semitones);
  }

  /// 序列化：`{"M6": {"m6": 12, "P5": 2}}`，键用 `storageId`，0 不落盘。
  ///
  /// 行与列都按半音数升序输出，保证同样的数据产生同样的 JSON 字节。
  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    final rows = _counts.keys.toList()
      ..sort((a, b) => a.semitones.compareTo(b.semitones));
    for (final actual in rows) {
      final row = _counts[actual]!;
      final cells = <String, dynamic>{};
      final columns = row.keys.toList()
        ..sort((a, b) => a.semitones.compareTo(b.semitones));
      for (final selected in columns) {
        final value = row[selected]!;
        if (value > 0) {
          cells[selected.storageId] = value;
        }
      }
      if (cells.isNotEmpty) {
        out[actual.storageId] = cells;
      }
    }
    return out;
  }

  /// 反序列化。未知 `storageId` 与非正整数直接跳过（前向兼容）。
  factory ConfusionMatrix.fromJson(Map<String, dynamic> json) {
    final matrix = ConfusionMatrix();
    for (final row in json.entries) {
      final actual = IntervalId.tryFromStorageId(row.key);
      if (actual == null) {
        continue;
      }
      final cells = row.value;
      if (cells is! Map) {
        continue;
      }
      for (final cell in cells.entries) {
        final selected = IntervalId.tryFromStorageId(cell.key);
        final value = cell.value;
        if (selected == null || value is! num || value <= 0) {
          continue;
        }
        matrix.increment(actual, selected, by: value.toInt());
      }
    }
    return matrix;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! ConfusionMatrix) {
      return false;
    }
    if (_counts.length != other._counts.length) {
      return false;
    }
    for (final row in _counts.entries) {
      final otherRow = other._counts[row.key];
      if (otherRow == null || otherRow.length != row.value.length) {
        return false;
      }
      for (final cell in row.value.entries) {
        if (otherRow[cell.key] != cell.value) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  int get hashCode {
    // 用「与遍历顺序无关」的异或聚合：Map 的迭代顺序不保证跨实例一致，
    // 若按顺序 hash，两个相等的矩阵可能算出不同的 hashCode。
    var acc = 0;
    for (final row in _counts.entries) {
      for (final cell in row.value.entries) {
        acc ^= Object.hash(row.key, cell.key, cell.value);
      }
    }
    return acc;
  }

  @override
  String toString() => 'ConfusionMatrix(${_counts.length} rows, '
      'total=$totalCount)';
}
