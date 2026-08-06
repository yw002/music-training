import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/color_schemes.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/app/theme/elevation_tokens.dart';
import 'package:interval_ear/app/theme/gradient_tokens.dart';
import 'package:interval_ear/app/theme/interval_palette.dart';
import 'package:interval_ear/app/theme/radius.dart';
import 'package:interval_ear/app/theme/semantic_colors.dart';
import 'package:interval_ear/app/theme/spacing.dart';
import 'package:interval_ear/app/theme/typography.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// 应用主题装配（架构 §1.7）。
///
/// `ThemeData(useMaterial3: true)` + 6 个 `ThemeExtension`：
/// `AppSemanticColors / AppGradients / AppElevations / AppIntervalPalette /
///  AppTextExtras / AppMotionTokens`，统一经 `context.tokens` 访问。
abstract final class AppTheme {
  /// 把领域层 [ThemePreference] 映射为 flutter `ThemeMode`（表现层映射集中处，
  /// 避免散落到各个页面；架构 §1.2 / §8.6）。
  static ThemeMode themeModeFor(ThemePreference preference) => switch (preference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  /// 浅色主题。
  static ThemeData get light => _build(Brightness.light);

  /// 深色主题（PRD 推荐默认体验）。
  static ThemeData get dark => _build(Brightness.dark);

  /// 按亮度取主题。
  static ThemeData of(Brightness brightness) => _build(brightness);

  /// 6 个 `ThemeExtension` 的装配结果，单测可直接取用。
  static List<ThemeExtension<dynamic>> extensionsFor(Brightness brightness) =>
      <ThemeExtension<dynamic>>[
        AppSemanticColors.of(brightness),
        AppGradients.of(brightness),
        AppElevations.of(brightness),
        AppIntervalPalette.of(brightness),
        AppTextExtras.standard(),
        const AppMotionTokens.standard(),
      ];

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = AppColorSchemes.of(brightness);
    final AppSemanticColors semantic = AppSemanticColors.of(brightness);
    final AppElevations elevations = AppElevations.of(brightness);
    final TextTheme textTheme = AppText.buildTextTheme();
    const AppRadius radius = AppRadius.instance;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: extensionsFor(brightness),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: elevations.e2.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius.card),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevations.e5.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius.dialog),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevations.e4.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: radius.bottomSheet),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius.card),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: SpacingScale.md,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevations.e1.surface,
        selectedColor: semantic.answerSurfaceSelected,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: radius.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingScale.sm,
          vertical: SpacingScale.xxs,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevations.e1.surface,
        border: OutlineInputBorder(
          borderRadius: radius.field,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius.field,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius.field,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SpacingScale.md,
          vertical: SpacingScale.sm,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, SpacingScale.minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: radius.button),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: SpacingScale.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, SpacingScale.minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: radius.button),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: SpacingScale.lg),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, SpacingScale.minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: radius.button),
          textStyle: textTheme.labelLarge,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 8,
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? Colors.transparent : null,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: radius.field,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }
}
