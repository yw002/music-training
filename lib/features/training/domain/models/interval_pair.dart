import 'package:equatable/equatable.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';

/// 一对音程（二选一强化训练与混淆分析的基本单位）。
///
/// **规范化**：`(M6, m6)` 与 `(m6, M6)` 在业务上是同一对，因此对外暴露的
/// [key] 与 `==` 都基于 [normalized]（按半音数升序）。若不规范化，统计时会
/// 把同一对薄弱音程拆成两条，弱项排行会出现重复项。
class IntervalPair extends Equatable {
  /// 创建一对音程。允许 `a == b`（虽然业务上无意义，由调用方校验）。
  const IntervalPair(this.a, this.b);

  /// 由存储键 `"m6|M6"` 解析。任一侧未知则返回 `null`。
  static IntervalPair? tryFromKey(String key) {
    final parts = key.split(keySeparator);
    if (parts.length != 2) {
      return null;
    }
    final left = IntervalId.tryFromStorageId(parts[0]);
    final right = IntervalId.tryFromStorageId(parts[1]);
    if (left == null || right == null) {
      return null;
    }
    return IntervalPair(left, right).normalized();
  }

  /// 存储键的分隔符。选 `|` 是因为它不会出现在任何 `storageId` 里。
  static const String keySeparator = '|';

  /// 第一个音程。
  final IntervalId a;

  /// 第二个音程。
  final IntervalId b;

  /// 半音数较小的一侧。
  IntervalId get low => a.semitones <= b.semitones ? a : b;

  /// 半音数较大的一侧。
  IntervalId get high => a.semitones <= b.semitones ? b : a;

  /// 两个音程的半音距离。
  int get semitoneDistance => (a.semitones - b.semitones).abs();

  /// 是否为退化对（两侧相同）。
  bool get isDegenerate => a == b;

  /// 返回按半音数升序排列的等价对。
  IntervalPair normalized() =>
      a.semitones <= b.semitones ? this : IntervalPair(b, a);

  /// 稳定的存储键，形如 `"m6|M6"`（始终按半音数升序）。
  String key() => '${low.storageId}$keySeparator${high.storageId}';

  /// 该对是否包含 [id]。
  bool contains(IntervalId id) => a == id || b == id;

  /// 给定其中一侧，返回另一侧；[id] 不属于本对时返回 `null`。
  IntervalId? other(IntervalId id) {
    if (id == a) {
      return b;
    }
    if (id == b) {
      return a;
    }
    return null;
  }

  /// 两个成员组成的集合。
  Set<IntervalId> toSet() => <IntervalId>{a, b};

  /// 复制并覆盖部分字段。
  IntervalPair copyWith({IntervalId? a, IntervalId? b}) =>
      IntervalPair(a ?? this.a, b ?? this.b);

  /// 序列化：直接用存储键，比 `{"a":..,"b":..}` 更省空间且天然规范化。
  Map<String, dynamic> toJson() => <String, dynamic>{'key': key()};

  /// 反序列化。键缺失或非法时降级为 `(纯一度, 纯一度)`，不抛异常。
  factory IntervalPair.fromJson(Map<String, dynamic> json) {
    final parsed = tryFromKey(json['key'] as String? ?? '');
    return parsed ??
        const IntervalPair(IntervalId.perfectUnison, IntervalId.perfectUnison);
  }

  @override
  List<Object?> get props => <Object?>[low, high];

  @override
  String toString() => 'IntervalPair(${key()})';
}
