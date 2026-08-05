import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/music_interval.dart';

/// 13 个音程的权威定义表（原规范第四章 / 架构 §3.1）。
///
/// 全项目**唯一**的音程元数据来源：中文名、英文简称、半音数、`storageId`、
/// glyph 形状都从这里取，任何地方都不许再硬编码音程名。
abstract final class IntervalCatalog {
  const IntervalCatalog._();

  /// 全部 13 个音程，按半音数升序。下标即半音数。
  static const List<MusicInterval> all = <MusicInterval>[
    MusicInterval(
      id: IntervalId.perfectUnison,
      nameZh: '纯一度',
      shorthand: 'P1',
      glyph: IntervalGlyphShape.filledCircleSmall,
      description: '同音重复，两音音高完全相同',
    ),
    MusicInterval(
      id: IntervalId.minorSecond,
      nameZh: '小二度',
      shorthand: 'm2',
      glyph: IntervalGlyphShape.outlinedDiamond,
      description: '最窄的音程，听感紧张、摩擦',
    ),
    MusicInterval(
      id: IntervalId.majorSecond,
      nameZh: '大二度',
      shorthand: 'M2',
      glyph: IntervalGlyphShape.filledDiamond,
      description: '相邻全音，音阶级进的基本步长',
    ),
    MusicInterval(
      id: IntervalId.minorThird,
      nameZh: '小三度',
      shorthand: 'm3',
      glyph: IntervalGlyphShape.outlinedRoundedSquare,
      description: '小调色彩的核心，柔和略暗',
    ),
    MusicInterval(
      id: IntervalId.majorThird,
      nameZh: '大三度',
      shorthand: 'M3',
      glyph: IntervalGlyphShape.filledRoundedSquare,
      description: '大调色彩的核心，明亮开阔',
    ),
    MusicInterval(
      id: IntervalId.perfectFourth,
      nameZh: '纯四度',
      shorthand: 'P4',
      glyph: IntervalGlyphShape.outlinedCircle,
      description: '稳定而空旷，常见于号角式动机',
    ),
    MusicInterval(
      id: IntervalId.tritone,
      nameZh: '增四度 / 减五度',
      shorthand: 'TT',
      glyph: IntervalGlyphShape.hexagon,
      description: '三全音，八度的正中点，极不稳定',
    ),
    MusicInterval(
      id: IntervalId.perfectFifth,
      nameZh: '纯五度',
      shorthand: 'P5',
      glyph: IntervalGlyphShape.filledCircleLarge,
      description: '除八度外最协和的音程，空心饱满',
    ),
    MusicInterval(
      id: IntervalId.minorSixth,
      nameZh: '小六度',
      shorthand: 'm6',
      glyph: IntervalGlyphShape.outlinedTriangle,
      description: '大三度的转位，忧郁而抒情',
    ),
    MusicInterval(
      id: IntervalId.majorSixth,
      nameZh: '大六度',
      shorthand: 'M6',
      glyph: IntervalGlyphShape.filledTriangle,
      description: '小三度的转位，舒展明朗',
    ),
    MusicInterval(
      id: IntervalId.minorSeventh,
      nameZh: '小七度',
      shorthand: 'm7',
      glyph: IntervalGlyphShape.outlinedPentagon,
      description: '属七和弦的骨架音，略带悬置感',
    ),
    MusicInterval(
      id: IntervalId.majorSeventh,
      nameZh: '大七度',
      shorthand: 'M7',
      glyph: IntervalGlyphShape.filledPentagon,
      description: '只差半音就到八度，尖锐而渴望解决',
    ),
    MusicInterval(
      id: IntervalId.perfectOctave,
      nameZh: '纯八度',
      shorthand: 'P8',
      glyph: IntervalGlyphShape.doubleRing,
      description: '同名音的高低八度，听感几乎融为一体',
    ),
  ];

  /// 可参与训练的音程（当前 13 个全部可训练）。
  static List<MusicInterval> get trainable =>
      all.where((interval) => interval.trainable).toList(growable: false);

  /// 全部音程 id，按半音数升序。
  static List<IntervalId> get allIds =>
      all.map((interval) => interval.id).toList(growable: false);

  /// 可训练音程 id 集合。
  static Set<IntervalId> get trainableIds =>
      trainable.map((interval) => interval.id).toSet();

  /// 取某个音程的定义。
  static MusicInterval of(IntervalId id) => all[id.semitones];

  /// 按半音数取定义。越界抛 [RangeError]。
  static MusicInterval bySemitones(int semitones) =>
      of(IntervalId.fromSemitones(semitones));

  /// 由 `storageId` 反查音程 id，未知返回 `null`。
  static IntervalId? fromStorageId(String storageId) =>
      IntervalId.tryFromStorageId(storageId);

  /// 中文名。
  static String nameOf(IntervalId id) => of(id).nameZh;

  /// 英文简称。
  static String shorthandOf(IntervalId id) => of(id).shorthand;

  /// 形状 glyph。
  static IntervalGlyphShape glyphOf(IntervalId id) => of(id).glyph;

  /// 把一组音程 id 按半音数升序排列。
  ///
  /// 出题时答案选项的渲染顺序必须**只由半音数决定**：如果顺序随正确答案变化，
  /// 用户就能从选项排布反推答案（PRD §3.1 防泄露）。
  static List<IntervalId> sorted(Iterable<IntervalId> ids) {
    final list = ids.toSet().toList()
      ..sort((a, b) => a.semitones.compareTo(b.semitones));
    return List<IntervalId>.unmodifiable(list);
  }
}
