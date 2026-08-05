import 'package:flutter/material.dart';

/// PRD §2.1 的两套完整 `ColorScheme`。
///
/// **不使用 `ColorScheme.fromSeed`**（架构 §1.7 明确否决）：PRD 给出了完整两套
/// 色值，种子生成的结果与设计稿不一致，必须逐个手填。
abstract final class AppColorSchemes {
  /// 浅色主题色板（PRD §2.1.1）。
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF5B4BE0),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE4E0FF),
    onPrimaryContainer: Color(0xFF150066),
    // 对比度修正：原 #00B0A2 与 onSecondary(#FFF) 仅 2.72:1，压深至 4.83:1。
    secondary: Color(0xFF008075),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFAFF5EC),
    onSecondaryContainer: Color(0xFF00201C),
    // 对比度修正：原 #E8467F 与 onTertiary(#FFF) 仅 3.74:1，压深至 5.12:1。
    tertiary: Color(0xFFD41A5C),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFD9E3),
    onTertiaryContainer: Color(0xFF3E001D),
    error: Color(0xFFD8353B),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDDDE),
    onErrorContainer: Color(0xFF5F0009),
    surface: Color(0xFFFCFBFF),
    onSurface: Color(0xFF1B1B21),
    surfaceDim: Color(0xFFDCD9E3),
    surfaceBright: Color(0xFFFCFBFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF6F3FC),
    surfaceContainer: Color(0xFFF0EDF7),
    surfaceContainerHigh: Color(0xFFEAE7F1),
    surfaceContainerHighest: Color(0xFFE4E1EC),
    onSurfaceVariant: Color(0xFF47464F),
    outline: Color(0xFF787680),
    outlineVariant: Color(0xFFC8C5D0),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
    inverseSurface: Color(0xFF302F36),
    onInverseSurface: Color(0xFFF3EFF7),
    inversePrimary: Color(0xFFC6BFFF),
    surfaceTint: Color(0xFF5B4BE0),
  );

  /// 深色主题色板（PRD §2.1.2，**推荐默认体验**）。
  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFC6BFFF),
    onPrimary: Color(0xFF2A1B8C),
    primaryContainer: Color(0xFF4235C4),
    onPrimaryContainer: Color(0xFFE4E0FF),
    secondary: Color(0xFF4FE3D0),
    onSecondary: Color(0xFF003731),
    secondaryContainer: Color(0xFF00544B),
    onSecondaryContainer: Color(0xFFAFF5EC),
    tertiary: Color(0xFFFFB1C6),
    onTertiary: Color(0xFF5E1133),
    tertiaryContainer: Color(0xFF7D2949),
    onTertiaryContainer: Color(0xFFFFD9E3),
    error: Color(0xFFFF7A80),
    onError: Color(0xFF5F0009),
    errorContainer: Color(0xFF5F0009),
    onErrorContainer: Color(0xFFFFDDDE),
    surface: Color(0xFF0F0E13),
    onSurface: Color(0xFFE5E1E9),
    surfaceDim: Color(0xFF0B0A0F),
    surfaceBright: Color(0xFF35333B),
    surfaceContainerLowest: Color(0xFF0A0910),
    surfaceContainerLow: Color(0xFF17161D),
    surfaceContainer: Color(0xFF1B1A22),
    surfaceContainerHigh: Color(0xFF26242D),
    surfaceContainerHighest: Color(0xFF312F38),
    onSurfaceVariant: Color(0xFFC8C5D0),
    outline: Color(0xFF928F9A),
    outlineVariant: Color(0xFF47464F),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
    inverseSurface: Color(0xFFE5E1E9),
    onInverseSurface: Color(0xFF1B1B21),
    inversePrimary: Color(0xFF5B4BE0),
    surfaceTint: Color(0xFFC6BFFF),
  );

  /// 遮罩不透明度：浅色 32%，深色 56%（PRD §2.1）。
  static double scrimOpacityOf(Brightness brightness) =>
      brightness == Brightness.light ? 0.32 : 0.56;

  /// 按亮度取色板。
  static ColorScheme of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;
}
