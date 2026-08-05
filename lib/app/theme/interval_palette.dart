import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 音程标识形状 glyph（PRD §2.2 表格最后一列）。
///
/// 色盲可辨规则要求「颜色 + 形状 + 数字」中至少两条同时成立，形状由
/// `CustomPainter` 按本枚举绘制，尺寸 12 / 16 / 20 三档。
enum IntervalGlyph {
  /// ● 实心圆（小）— 纯一度。
  filledCircleSmall,

  /// ◇ 空心菱形 — 小二度。
  outlinedDiamond,

  /// ◆ 实心菱形 — 大二度。
  filledDiamond,

  /// ▢ 空心圆角方 — 小三度。
  outlinedRoundedSquare,

  /// ▣ 实心圆角方 — 大三度。
  filledRoundedSquare,

  /// ○ 空心圆 — 纯四度。
  outlinedCircle,

  /// ⬡ 六边形（唯一）— 三全音。
  hexagon,

  /// ● 实心圆（大）— 纯五度。
  filledCircleLarge,

  /// ▽ 空心三角 — 小六度。
  outlinedTriangle,

  /// ▼ 实心三角 — 大六度。
  filledTriangle,

  /// ⬠ 空心五边形 — 小七度。
  outlinedPentagon,

  /// ⬟ 实心五边形 — 大七度。
  filledPentagon,

  /// ◎ 双环 — 纯八度。
  doubleRing,
}

/// 13 音程标识色扩展（PRD §2.2）。
///
/// **常量表，不做运行时 HSL 计算**（PRD §2.2 明确要求）。生成规则备查：
/// 半音数 `n ∈ [0,12]` → 色相 `H = (255 + 27 × n) mod 360`；
/// 浅色 `HSL(H, 72%, 46%)`，深色 `HSL(H, 78%, 68%)`。
///
/// 索引口径：**半音数 0..12**。领域层的 `IntervalId` 持有 `semitones` 字段，
/// 调用处写 `context.tokens.interval.colorOf(id.semitones)`。这样 `app/theme`
/// 不需要依赖 `features/` 的领域模型，符合架构 §8 的分层约束。
@immutable
class AppIntervalPalette extends ThemeExtension<AppIntervalPalette> {
  /// 创建音程色板。
  const AppIntervalPalette({required this.colors});

  /// 13 个音程色，下标即半音数。
  final List<Color> colors;

  /// 半音数上限（纯八度）。
  static const int maxSemitones = 12;

  /// 各半音数对应的色相（度）。仅用于单测校验，运行时不参与计算。
  static const List<int> hues = <int>[
    255, 282, 309, 336, 3, 30, 57, 84, 111, 138, 165, 192, 219,
  ];

  /// 各半音数对应的形状 glyph。
  static const List<IntervalGlyph> glyphs = <IntervalGlyph>[
    IntervalGlyph.filledCircleSmall,
    IntervalGlyph.outlinedDiamond,
    IntervalGlyph.filledDiamond,
    IntervalGlyph.outlinedRoundedSquare,
    IntervalGlyph.filledRoundedSquare,
    IntervalGlyph.outlinedCircle,
    IntervalGlyph.hexagon,
    IntervalGlyph.filledCircleLarge,
    IntervalGlyph.outlinedTriangle,
    IntervalGlyph.filledTriangle,
    IntervalGlyph.outlinedPentagon,
    IntervalGlyph.filledPentagon,
    IntervalGlyph.doubleRing,
  ];

  /// 英文简称（P1/m2/…），受设置项 `showIntervalShorthand` 控制显示。
  static const List<String> shorthands = <String>[
    'P1', 'm2', 'M2', 'm3', 'M3', 'P4', 'TT', 'P5', 'm6', 'M6', 'm7', 'M7',
    'P8',
  ];

  /// 浅色音程色板 `HSL(H, 72%, 46%)`。
  static const AppIntervalPalette light = AppIntervalPalette(
    colors: <Color>[
      Color(0xFF4B21CA), // 0  纯一度   P1  H=255
      Color(0xFF9721CA), // 1  小二度   m2  H=282
      Color(0xFFCA21B0), // 2  大二度   M2  H=309
      Color(0xFFCA2164), // 3  小三度   m3  H=336
      Color(0xFFCA2921), // 4  大三度   M3  H=3
      Color(0xFFCA7521), // 5  纯四度   P4  H=30
      Color(0xFFCAC121), // 6  增四减五 TT  H=57
      Color(0xFF86CA21), // 7  纯五度   P5  H=84
      Color(0xFF3ACA21), // 8  小六度   m6  H=111
      Color(0xFF21CA54), // 9  大六度   M6  H=138
      Color(0xFF21CAA0), // 10 小七度   m7  H=165
      Color(0xFF21A8CA), // 11 大七度   M7  H=192
      Color(0xFF215CCA), // 12 纯八度   P8  H=219
    ],
  );

  /// 深色音程色板 `HSL(H, 78%, 68%)`。
  static const AppIntervalPalette dark = AppIntervalPalette(
    colors: <Color>[
      Color(0xFF8E6EED), // 0  P1
      Color(0xFFC76EED), // 1  m2
      Color(0xFFED6EDA), // 2  M2
      Color(0xFFED6EA1), // 3  m3
      Color(0xFFED746E), // 4  M3
      Color(0xFFEDAD6E), // 5  P4
      Color(0xFFEDE76E), // 6  TT
      Color(0xFFBAED6E), // 7  P5
      Color(0xFF81ED6E), // 8  m6
      Color(0xFF6EED94), // 9  M6
      Color(0xFF6EEDCD), // 10 m7
      Color(0xFF6ED4ED), // 11 M7
      Color(0xFF6E9AED), // 12 P8
    ],
  );

  /// 按亮度取色板。
  static AppIntervalPalette of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  /// 取半音数对应的标识色。越界会被 clamp 到 `[0, 12]`。
  Color colorOf(int semitones) => colors[semitones.clamp(0, maxSemitones)];

  /// 取半音数对应的形状 glyph。
  IntervalGlyph glyphOf(int semitones) =>
      glyphs[semitones.clamp(0, maxSemitones)];

  /// 取半音数对应的英文简称。
  String shorthandOf(int semitones) =>
      shorthands[semitones.clamp(0, maxSemitones)];

  /// 该半音数是否与 success 语义色相近（PRD §2.2.1 附加规则）。
  ///
  /// 小六度 `#3ACA21` 与 success 色相接近，禁止与对错反馈状态色并列展示。
  bool conflictsWithSuccess(int semitones) => semitones == 8;

  @override
  AppIntervalPalette copyWith({List<Color>? colors}) =>
      AppIntervalPalette(colors: colors ?? this.colors);

  @override
  AppIntervalPalette lerp(
    covariant ThemeExtension<AppIntervalPalette>? other,
    double t,
  ) {
    if (other is! AppIntervalPalette) {
      return this;
    }
    return AppIntervalPalette(
      colors: <Color>[
        for (int i = 0; i <= maxSemitones; i++)
          Color.lerp(colors[i], other.colors[i], t)!,
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppIntervalPalette && listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hashAll(colors);
}
