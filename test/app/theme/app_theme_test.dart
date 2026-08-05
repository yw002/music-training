import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/app/theme/color_schemes.dart';
import 'package:interval_ear/app/theme/elevation_tokens.dart';
import 'package:interval_ear/app/theme/gradient_tokens.dart';
import 'package:interval_ear/app/theme/interval_palette.dart';
import 'package:interval_ear/app/theme/radius.dart';
import 'package:interval_ear/app/theme/semantic_colors.dart';
import 'package:interval_ear/app/theme/spacing.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/app/theme/typography.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// T02 验收项：
/// - 6 个 `ThemeExtension` 全部挂载，且 `copyWith` / `lerp` 契约完备；
/// - `context.tokens.color / .motion / .space` 等访问器可用（架构 §8.3）；
/// - `AppText.numeric*` 全部启用 `FontFeature.tabularFigures()`；
/// - `kLatinFontFamily == null`（PRD §0.3 字体策略 B，禁止 google_fonts）。
void main() {
  group('AppTheme 装配', () {
    test('light / dark 使用 Material 3 且色板匹配', () {
      expect(AppTheme.light.useMaterial3, isTrue);
      expect(AppTheme.dark.useMaterial3, isTrue);
      expect(AppTheme.light.colorScheme, AppColorSchemes.light);
      expect(AppTheme.dark.colorScheme, AppColorSchemes.dark);
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('of(brightness) 与 light / dark 一致', () {
      expect(AppTheme.of(Brightness.light).colorScheme, AppTheme.light.colorScheme);
      expect(AppTheme.of(Brightness.dark).colorScheme, AppTheme.dark.colorScheme);
    });

    test('6 个 ThemeExtension 全部挂载', () {
      for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
        expect(theme.extension<AppSemanticColors>(), isNotNull);
        expect(theme.extension<AppGradients>(), isNotNull);
        expect(theme.extension<AppElevations>(), isNotNull);
        expect(theme.extension<AppIntervalPalette>(), isNotNull);
        expect(theme.extension<AppTextExtras>(), isNotNull);
        expect(theme.extension<AppMotionTokens>(), isNotNull);
        expect(theme.extensions.length, greaterThanOrEqualTo(6));
      }
    });

    test('extensionsFor 按亮度返回正确实例', () {
      final ThemeData light = AppTheme.light;
      expect(light.extension<AppSemanticColors>(), AppSemanticColors.light);
      expect(light.extension<AppIntervalPalette>(), AppIntervalPalette.light);
      expect(light.extension<AppGradients>(), AppGradients.light);

      final ThemeData dark = AppTheme.dark;
      expect(dark.extension<AppSemanticColors>(), AppSemanticColors.dark);
      expect(dark.extension<AppIntervalPalette>(), AppIntervalPalette.dark);
      expect(dark.extension<AppGradients>(), AppGradients.dark);
    });

    test('scaffold / appBar 背景取自色板', () {
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColorSchemes.dark.surface);
      expect(AppTheme.light.scaffoldBackgroundColor, AppColorSchemes.light.surface);
    });
  });

  group('ThemeExtension copyWith / lerp 契约', () {
    test('AppGradients', () {
      const AppGradients a = AppGradients.light;
      const AppGradients b = AppGradients.dark;
      expect(a.copyWith(), a);
      expect(a.copyWith(brand: b.brand).brand, b.brand);
      expect(a.lerp(null, 0.5), same(a), reason: '非同类型必须返回自身');
      expect(a.lerp(b, 0.0).brand.colors.first, a.brand.colors.first);
      expect(a.lerp(b, 1.0).brand.colors.first, b.brand.colors.first);
      expect(a.lerp(b, 0.5), isA<AppGradients>());
    });

    test('AppElevations', () {
      const AppElevations a = AppElevations.light;
      const AppElevations b = AppElevations.dark;
      expect(a.copyWith(), a);
      expect(a.copyWith(e3: b.e3).e3, b.e3);
      expect(a.lerp(null, 0.5), same(a));
      expect(a.lerp(b, 0.0).e2.surface, a.e2.surface);
      expect(a.lerp(b, 1.0).e2.surface, b.e2.surface);
      expect(a.lerp(b, 0.5).e5.shadows.length, a.e5.shadows.length);
    });

    test('AppTextExtras', () {
      final AppTextExtras a = AppTextExtras.standard();
      expect(a.copyWith(), a);
      final AppTextExtras changed =
          a.copyWith(numericSmall: const TextStyle(fontSize: 99));
      expect(changed.numericSmall.fontSize, 99);
      expect(changed.numericLarge, a.numericLarge);
      expect(a.lerp(null, 0.5), same(a));
      expect(a.lerp(a, 0.5).numericLarge.fontSize, a.numericLarge.fontSize);
    });

    test('AppMotionTokens', () {
      const AppMotionTokens a = AppMotionTokens.standard();
      expect(a.copyWith(), a);
      expect(a.lerp(a, 0.5), a);
      expect(a.lerp(null, 0.5), a);
    });

    test('lerp 中点不抛异常且类型正确（主题切换动画路径）', () {
      for (double t = 0; t <= 1.0; t += 0.25) {
        expect(AppSemanticColors.light.lerp(AppSemanticColors.dark, t),
            isA<AppSemanticColors>());
        expect(AppGradients.light.lerp(AppGradients.dark, t), isA<AppGradients>());
        expect(AppElevations.light.lerp(AppElevations.dark, t), isA<AppElevations>());
        expect(
          AppIntervalPalette.light.lerp(AppIntervalPalette.dark, t),
          isA<AppIntervalPalette>(),
        );
      }
    });
  });

  group('字体策略 B（PRD §0.3）', () {
    test('kLatinFontFamily 为 null，完全依赖系统字体', () {
      expect(kLatinFontFamily, isNull);
    });

    test('fontFamilyFallback 覆盖三端中文字体', () {
      expect(kFontFamilyFallback, contains('PingFang SC'));
      expect(kFontFamilyFallback, contains('Microsoft YaHei UI'));
      expect(kFontFamilyFallback, contains('Noto Sans CJK SC'));
    });

    test('全部 numeric* 字号启用等宽数字', () {
      final List<(String, TextStyle)> numerics = <(String, TextStyle)>[
        ('numericDisplay', AppText.numericDisplay),
        ('numericLarge', AppText.numericLarge),
        ('numericMedium', AppText.numericMedium),
        ('numericSmall', AppText.numericSmall),
      ];
      for (final (String name, TextStyle style) in numerics) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: '$name 缺少 tabularFigures，倒计时/正确率会抖动',
        );
      }
    });

    test('AppTextExtras.standard() 的 numeric* 同样等宽', () {
      final AppTextExtras extras = AppTextExtras.standard();
      for (final TextStyle style in <TextStyle>[
        extras.numericDisplay,
        extras.numericLarge,
        extras.numericMedium,
        extras.numericSmall,
      ]) {
        expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      }
    });

    test('正文字号不启用等宽数字（避免正文字距怪异）', () {
      expect(AppText.bodyMedium.fontFeatures ?? const <FontFeature>[],
          isNot(contains(const FontFeature.tabularFigures())));
    });

    test('全部字号都设置了 height，避免行高塌陷', () {
      final List<TextStyle> styles = <TextStyle>[
        AppText.displayLarge,
        AppText.displayMedium,
        AppText.displaySmall,
        AppText.headlineLarge,
        AppText.headlineMedium,
        AppText.headlineSmall,
        AppText.titleLarge,
        AppText.titleMedium,
        AppText.titleSmall,
        AppText.bodyLarge,
        AppText.bodyMedium,
        AppText.bodySmall,
        AppText.labelLarge,
        AppText.labelMedium,
        AppText.labelSmall,
        AppText.answerButtonLabel,
        AppText.answerButtonLabelXL,
        AppText.numericDisplay,
        AppText.numericLarge,
        AppText.numericMedium,
        AppText.numericSmall,
      ];
      for (final TextStyle s in styles) {
        expect(s.fontSize, isNotNull);
        expect(s.height, isNotNull);
        expect(s.height, greaterThan(0.9));
        expect(s.fontFamily, isNull, reason: '不得硬编码字体族（禁止 google_fonts）');
      }
    });

    test('buildTextTheme 填满 15 个 Material 槽位', () {
      final TextTheme t = AppText.buildTextTheme();
      for (final TextStyle? s in <TextStyle?>[
        t.displayLarge, t.displayMedium, t.displaySmall,
        t.headlineLarge, t.headlineMedium, t.headlineSmall,
        t.titleLarge, t.titleMedium, t.titleSmall,
        t.bodyLarge, t.bodyMedium, t.bodySmall,
        t.labelLarge, t.labelMedium, t.labelSmall,
      ]) {
        expect(s, isNotNull);
      }
    });
  });

  group('间距与圆角标尺', () {
    test('间距为严格递增的偶数 dp', () {
      const AppSpacing s = AppSpacing.instance;
      final List<double> scale = <double>[
        s.xxs, s.xs, s.sm, s.md, s.lg, s.xl, s.xxl, s.xxxl,
      ];
      for (int i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]), reason: 'index=$i');
      }
      for (final double v in scale) {
        expect(v % 2, 0, reason: '$v 不是偶数 dp');
      }
    });

    test('断点单调递增', () {
      expect(AppBreakpoints.medium, lessThan(AppBreakpoints.expanded));
      expect(AppBreakpoints.expanded, lessThan(AppBreakpoints.large));
    });

    test('圆角命名令牌落在标尺内', () {
      const AppRadius r = AppRadius.instance;
      expect(r.card.topLeft.x, 20);
      expect(r.bigCard.topLeft.x, 28);
      expect(r.answerButton.topLeft.x, 20);
      expect(r.binaryButton.topLeft.x, 24);
      expect(r.bottomSheet.bottomLeft.x, 0, reason: '底部弹层只圆上方两角');
      expect(r.chartBar.bottomLeft.x, 0, reason: '柱状图只圆顶部');
    });
  });

  group('context.tokens 访问器（架构 §8.3）', () {
    testWidgets('深色主题下 6 类令牌都能取到且与扩展一致', (WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (BuildContext context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final AppTokens tokens = ctx.tokens;
      expect(tokens.isDark, isTrue);
      expect(tokens.scheme, AppColorSchemes.dark);
      expect(tokens.color, AppSemanticColors.dark);
      expect(tokens.gradient, AppGradients.dark);
      expect(tokens.elevation, AppElevations.dark);
      expect(tokens.interval, AppIntervalPalette.dark);
      expect(tokens.motion, const AppMotionTokens.standard());
      expect(tokens.space, AppSpacing.instance);
      expect(tokens.radius, AppRadius.instance);
      expect(tokens.type.bodyMedium, isNotNull);
      expect(tokens.text.numericLarge.fontFeatures,
          contains(const FontFeature.tabularFigures()));
    });

    testWidgets('浅色主题下访问器切换到浅色令牌', (WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (BuildContext context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(ctx.tokens.isDark, isFalse);
      expect(ctx.tokens.color, AppSemanticColors.light);
      expect(ctx.tokens.interval, AppIntervalPalette.light);
    });

    testWidgets('主题未挂载扩展时访问器回落到默认值而不是崩溃', (WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (BuildContext context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(ctx.tokens.color, AppSemanticColors.light);
      expect(ctx.tokens.gradient, AppGradients.light);
      expect(ctx.tokens.elevation, AppElevations.light);
      expect(ctx.tokens.interval, AppIntervalPalette.light);
      expect(ctx.tokens.motion, const AppMotionTokens.standard());
      expect(ctx.tokens.text, AppTextExtras.standard());
    });
  });
}
