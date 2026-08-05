import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/app/theme/color_schemes.dart';
import 'package:interval_ear/app/theme/semantic_colors.dart';

/// T02 验收项：正文对比度 ≥ 4.5:1，大字号 / 非文本 UI 元素 ≥ 3:1（WCAG 2.1 AA）。
///
/// 对比度按 WCAG 相对亮度公式计算，与浏览器 / Chrome DevTools 口径一致。
void main() {
  /// sRGB 分量线性化。
  double linearize(int channel) {
    final double c = channel / 255.0;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// WCAG 相对亮度。
  double relativeLuminance(Color color) {
    final int argb = color.toARGB32();
    final int r = (argb >> 16) & 0xFF;
    final int g = (argb >> 8) & 0xFF;
    final int b = argb & 0xFF;
    return 0.2126 * linearize(r) +
        0.7152 * linearize(g) +
        0.0722 * linearize(b);
  }

  /// WCAG 对比度：`(L_light + 0.05) / (L_dark + 0.05)`。
  double contrastRatio(Color a, Color b) {
    final double la = relativeLuminance(a);
    final double lb = relativeLuminance(b);
    final double hi = math.max(la, lb);
    final double lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  void expectBodyContrast(Color fg, Color bg, String label) {
    final double ratio = contrastRatio(fg, bg);
    expect(
      ratio,
      greaterThanOrEqualTo(4.5),
      reason: '$label 对比度仅 ${ratio.toStringAsFixed(2)}:1，正文要求 ≥ 4.5:1',
    );
  }

  void expectLargeContrast(Color fg, Color bg, String label) {
    final double ratio = contrastRatio(fg, bg);
    expect(
      ratio,
      greaterThanOrEqualTo(3.0),
      reason: '$label 对比度仅 ${ratio.toStringAsFixed(2)}:1，大字号/UI 要求 ≥ 3:1',
    );
  }

  group('对比度计算器自校验', () {
    test('黑白极值 = 21:1，同色 = 1:1', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1.0, 1e-9));
    });

    test('对称性：交换前后景不改变结果', () {
      const Color a = Color(0xFF5B4BE0);
      const Color b = Color(0xFFFCFBFF);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-12));
    });
  });

  for (final (String name, ColorScheme scheme) in <(String, ColorScheme)>[
    ('light', AppColorSchemes.light),
    ('dark', AppColorSchemes.dark),
  ]) {
    group('ColorScheme.$name 对比度', () {
      test('全部 on* / 底色配对 ≥ 4.5:1', () {
        final List<(Color, Color, String)> pairs = <(Color, Color, String)>[
          (scheme.onPrimary, scheme.primary, 'onPrimary/primary'),
          (scheme.onSecondary, scheme.secondary, 'onSecondary/secondary'),
          (scheme.onTertiary, scheme.tertiary, 'onTertiary/tertiary'),
          (scheme.onError, scheme.error, 'onError/error'),
          (
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
            'onPrimaryContainer/primaryContainer',
          ),
          (
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
            'onSecondaryContainer/secondaryContainer',
          ),
          (
            scheme.onTertiaryContainer,
            scheme.tertiaryContainer,
            'onTertiaryContainer/tertiaryContainer',
          ),
          (
            scheme.onErrorContainer,
            scheme.errorContainer,
            'onErrorContainer/errorContainer',
          ),
          (scheme.onSurface, scheme.surface, 'onSurface/surface'),
          (scheme.onSurfaceVariant, scheme.surface, 'onSurfaceVariant/surface'),
          (
            scheme.onInverseSurface,
            scheme.inverseSurface,
            'onInverseSurface/inverseSurface',
          ),
        ];
        for (final (Color fg, Color bg, String label) in pairs) {
          expectBodyContrast(fg, bg, '[$name] $label');
        }
      });

      test('正文色在全部 surfaceContainer* 层级上都 ≥ 4.5:1', () {
        final List<(Color, String)> surfaces = <(Color, String)>[
          (scheme.surfaceContainerLowest, 'surfaceContainerLowest'),
          (scheme.surfaceContainerLow, 'surfaceContainerLow'),
          (scheme.surfaceContainer, 'surfaceContainer'),
          (scheme.surfaceContainerHigh, 'surfaceContainerHigh'),
          (scheme.surfaceContainerHighest, 'surfaceContainerHighest'),
          (scheme.surfaceDim, 'surfaceDim'),
          (scheme.surfaceBright, 'surfaceBright'),
        ];
        for (final (Color bg, String label) in surfaces) {
          expectBodyContrast(scheme.onSurface, bg, '[$name] onSurface/$label');
          expectBodyContrast(
            scheme.onSurfaceVariant,
            bg,
            '[$name] onSurfaceVariant/$label',
          );
        }
      });

      test('outline 作为非文本 UI 元素在 surface 上 ≥ 3:1', () {
        expectLargeContrast(scheme.outline, scheme.surface, '[$name] outline/surface');
        expectLargeContrast(
          scheme.outline,
          scheme.surfaceContainerHighest,
          '[$name] outline/surfaceContainerHighest',
        );
      });

      test('brightness 与命名一致', () {
        expect(
          scheme.brightness,
          name == 'light' ? Brightness.light : Brightness.dark,
        );
      });
    });
  }

  for (final (String name, AppSemanticColors sem, ColorScheme scheme)
      in <(String, AppSemanticColors, ColorScheme)>[
    ('light', AppSemanticColors.light, AppColorSchemes.light),
    ('dark', AppSemanticColors.dark, AppColorSchemes.dark),
  ]) {
    group('AppSemanticColors.$name 对比度', () {
      test('success / warning / uncertain 的 on 与 base 配对 ≥ 4.5:1', () {
        expectBodyContrast(sem.success.on, sem.success.base, '[$name] success');
        expectBodyContrast(sem.warning.on, sem.warning.base, '[$name] warning');
        expectBodyContrast(sem.uncertain.on, sem.uncertain.base, '[$name] uncertain');
      });

      test('onContainer 与 container 配对 ≥ 4.5:1', () {
        expectBodyContrast(
          sem.success.onContainer,
          sem.success.container,
          '[$name] successContainer',
        );
        expectBodyContrast(
          sem.warning.onContainer,
          sem.warning.container,
          '[$name] warningContainer',
        );
        expectBodyContrast(
          sem.uncertain.onContainer,
          sem.uncertain.container,
          '[$name] uncertainContainer',
        );
      });

      test('base 色直接画在 surface 上（图标 / 边框）≥ 3:1', () {
        expectLargeContrast(sem.success.base, scheme.surface, '[$name] success/surface');
        expectLargeContrast(sem.warning.base, scheme.surface, '[$name] warning/surface');
        expectLargeContrast(
          sem.uncertain.base,
          scheme.surface,
          '[$name] uncertain/surface',
        );
      });

      test('答题按钮正文在三种答题面上都 ≥ 4.5:1', () {
        for (final (Color bg, String label) in <(Color, String)>[
          (sem.answerSurface, 'answerSurface'),
          (sem.answerSurfaceHover, 'answerSurfaceHover'),
          (sem.answerSurfaceSelected, 'answerSurfaceSelected'),
        ]) {
          expectBodyContrast(scheme.onSurface, bg, '[$name] onSurface/$label');
        }
      });
    });
  }

  group('AppSemanticColors 令牌契约', () {
    test('scrim / glow 透明度在合法区间', () {
      for (final AppSemanticColors sem in <AppSemanticColors>[
        AppSemanticColors.light,
        AppSemanticColors.dark,
      ]) {
        expect(sem.scrimOpacity, inInclusiveRange(0.0, 1.0));
        expect(sem.glowOpacity, inInclusiveRange(0.0, 1.0));
        expect(sem.glassBlurSigma, greaterThan(0.0));
      }
      expect(
        AppSemanticColors.dark.scrimOpacity,
        greaterThan(AppSemanticColors.light.scrimOpacity),
        reason: '深色下遮罩需要更重才能压住底层内容',
      );
    });

    test('copyWith 只改指定字段', () {
      const AppSemanticColors base = AppSemanticColors.light;
      final AppSemanticColors changed = base.copyWith(glowOpacity: 0.42);
      expect(changed.glowOpacity, 0.42);
      expect(changed.success, base.success);
      expect(changed.answerBorder, base.answerBorder);
      expect(base.copyWith(), base);
    });

    test('lerp 端点与中点', () {
      const AppSemanticColors a = AppSemanticColors.light;
      const AppSemanticColors b = AppSemanticColors.dark;
      expect(a.lerp(null, 0.5), same(a), reason: '非同类型必须返回自身');
      expect(a.lerp(b, 0.0).success.base, a.success.base);
      expect(a.lerp(b, 1.0).success.base, b.success.base);
      final AppSemanticColors mid = a.lerp(b, 0.5);
      expect(mid.success.base, Color.lerp(a.success.base, b.success.base, 0.5));
      expect(
        mid.scrimOpacity,
        closeTo((a.scrimOpacity + b.scrimOpacity) / 2, 1e-9),
      );
    });

    test('SemanticColorRole 相等性与 lerp', () {
      const SemanticColorRole r1 = SemanticColorRole(
        base: Color(0xFF112233),
        on: Color(0xFFFFFFFF),
        container: Color(0xFFAABBCC),
        onContainer: Color(0xFF000000),
      );
      const SemanticColorRole r2 = SemanticColorRole(
        base: Color(0xFF112233),
        on: Color(0xFFFFFFFF),
        container: Color(0xFFAABBCC),
        onContainer: Color(0xFF000000),
      );
      expect(r1, r2);
      expect(r1.hashCode, r2.hashCode);
      expect(SemanticColorRole.lerp(r1, r2, 0.5).base, r1.base);
    });
  });
}
