import 'package:equatable/equatable.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';

/// 音程标识形状（PRD §2.2 表格最后一列）。
///
/// **为什么这里要再定义一遍**：`lib/app/theme/interval_palette.dart` 里的
/// `IntervalGlyph` 是给 `CustomPainter` 用的，那个文件 `import 'package:flutter/...'`；
/// 而架构 §8.1 硬性规定 `features/*/domain/` 下禁止依赖 Flutter。所以领域层持有
/// 一份**纯 Dart 的形状语义枚举**，主题层负责把它翻译成画笔指令。
///
/// 两个枚举的成员名与顺序必须严格一致，`test/domain/interval_catalog_test.dart`
/// 里有一条对齐测试（测试文件可以 import Flutter）在 CI 上守住这条约束。
enum IntervalGlyphShape {
  /// ● 实心圆（小）。
  filledCircleSmall,

  /// ◇ 空心菱形。
  outlinedDiamond,

  /// ◆ 实心菱形。
  filledDiamond,

  /// ▢ 空心圆角方。
  outlinedRoundedSquare,

  /// ▣ 实心圆角方。
  filledRoundedSquare,

  /// ○ 空心圆。
  outlinedCircle,

  /// ⬡ 六边形（唯一，留给三全音）。
  hexagon,

  /// ● 实心圆（大）。
  filledCircleLarge,

  /// ▽ 空心三角。
  outlinedTriangle,

  /// ▼ 实心三角。
  filledTriangle,

  /// ⬠ 空心五边形。
  outlinedPentagon,

  /// ⬟ 实心五边形。
  filledPentagon,

  /// ◎ 双环。
  doubleRing,
}

/// 一个音程的静态定义（架构 §3.1）。
///
/// 这是**只读的领域常量数据**，不落盘（落盘的只有 [IntervalId.storageId]），
/// 因此不需要 `toJson` / `fromJson`——序列化的是引用它的模型，不是它本身。
class MusicInterval extends Equatable {
  /// 创建一条音程定义。
  const MusicInterval({
    required this.id,
    required this.nameZh,
    required this.shorthand,
    required this.glyph,
    required this.description,
    this.trainable = true,
  });

  /// 音程标识。
  final IntervalId id;

  /// 中文名（领域数据，按架构 §8.5 规则 3 不进 `AppStrings`）。
  final String nameZh;

  /// 英文简称，如 `P1` / `m2` / `TT`。
  final String shorthand;

  /// 色盲可辨用的形状。
  final IntervalGlyphShape glyph;

  /// 一句话说明，用于设置页与报告页的辅助文本。
  final String description;

  /// 是否参与训练。13 个音程当前全部可训练，字段留给将来「关闭纯一度」这类需求。
  final bool trainable;

  /// 半音数。
  int get semitones => id.semitones;

  /// 落盘 id。
  String get storageId => id.storageId;

  /// 排序权重：直接用半音数，保证列表在任何页面上顺序一致。
  int get sortOrder => id.semitones;

  /// 复制并覆盖部分字段。
  MusicInterval copyWith({
    IntervalId? id,
    String? nameZh,
    String? shorthand,
    IntervalGlyphShape? glyph,
    String? description,
    bool? trainable,
  }) =>
      MusicInterval(
        id: id ?? this.id,
        nameZh: nameZh ?? this.nameZh,
        shorthand: shorthand ?? this.shorthand,
        glyph: glyph ?? this.glyph,
        description: description ?? this.description,
        trainable: trainable ?? this.trainable,
      );

  @override
  List<Object?> get props =>
      <Object?>[id, nameZh, shorthand, glyph, description, trainable];

  @override
  String toString() => 'MusicInterval($storageId, $nameZh)';
}
