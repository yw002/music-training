import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/app/theme/interval_palette.dart';

/// T02 验收项：13 个音程标识色必须逐个通过 HSL 反算校验（PRD §2.2）。
///
/// 生成规则：半音数 `n ∈ [0,12]` → 色相 `H = (255 + 27 × n) mod 360`；
/// 浅色 `HSL(H, 72%, 46%)`，深色 `HSL(H, 78%, 68%)`。
/// 常量表里写的是十六进制，这里用 [HSLColor] 反算回 HSL 逐项比对，
/// 保证「表里的值」和「PRD 的公式」不会悄悄漂移。
void main() {
  /// 允许的舍入误差：8bit 量化后单通道最多差 1/255，折算到 H/S/L 上取如下容差。
  const double hueTolerance = 0.6;
  const double satTolerance = 0.01;
  const double lightTolerance = 0.005;

  group('色相公式', () {
    test('hues[n] == (255 + 27n) mod 360', () {
      expect(AppIntervalPalette.hues.length, 13);
      for (int n = 0; n <= AppIntervalPalette.maxSemitones; n++) {
        expect(
          AppIntervalPalette.hues[n],
          (255 + 27 * n) % 360,
          reason: 'semitones=$n',
        );
      }
    });

    test('13 个色相两两不同，且最小间隔 = 27°', () {
      final Set<int> unique = AppIntervalPalette.hues.toSet();
      expect(unique.length, 13);
      final List<int> sorted = AppIntervalPalette.hues.toList()..sort();
      for (int i = 1; i < sorted.length; i++) {
        expect(sorted[i] - sorted[i - 1], greaterThanOrEqualTo(27));
      }
    });
  });

  group('浅色板 HSL(H, 72%, 46%)', () {
    test('13 个色值逐个反算匹配', () {
      for (int n = 0; n <= AppIntervalPalette.maxSemitones; n++) {
        final HSLColor hsl = HSLColor.fromColor(AppIntervalPalette.light.colorOf(n));
        final double expectedHue = AppIntervalPalette.hues[n].toDouble();
        expect(
          hsl.hue,
          closeTo(expectedHue, hueTolerance),
          reason: 'semitones=$n 期望 H=$expectedHue',
        );
        expect(
          hsl.saturation,
          closeTo(0.72, satTolerance),
          reason: 'semitones=$n 期望 S=72%',
        );
        expect(
          hsl.lightness,
          closeTo(0.46, lightTolerance),
          reason: 'semitones=$n 期望 L=46%',
        );
        expect(hsl.alpha, 1.0);
      }
    });
  });

  group('深色板 HSL(H, 78%, 68%)', () {
    test('13 个色值逐个反算匹配', () {
      for (int n = 0; n <= AppIntervalPalette.maxSemitones; n++) {
        final HSLColor hsl = HSLColor.fromColor(AppIntervalPalette.dark.colorOf(n));
        final double expectedHue = AppIntervalPalette.hues[n].toDouble();
        expect(
          hsl.hue,
          closeTo(expectedHue, hueTolerance),
          reason: 'semitones=$n 期望 H=$expectedHue',
        );
        expect(
          hsl.saturation,
          closeTo(0.78, satTolerance),
          reason: 'semitones=$n 期望 S=78%',
        );
        expect(
          hsl.lightness,
          closeTo(0.68, lightTolerance),
          reason: 'semitones=$n 期望 L=68%',
        );
        expect(hsl.alpha, 1.0);
      }
    });

    test('深色板整体比浅色板更亮（暗背景可读性）', () {
      for (int n = 0; n <= AppIntervalPalette.maxSemitones; n++) {
        expect(
          HSLColor.fromColor(AppIntervalPalette.dark.colorOf(n)).lightness,
          greaterThan(
            HSLColor.fromColor(AppIntervalPalette.light.colorOf(n)).lightness,
          ),
          reason: 'semitones=$n',
        );
      }
    });
  });

  group('色盲可辨：颜色 + 形状 + 数字三选二', () {
    test('13 个 glyph 两两不同', () {
      expect(AppIntervalPalette.glyphs.length, 13);
      expect(AppIntervalPalette.glyphs.toSet().length, 13);
      expect(IntervalGlyph.values.length, 13);
    });

    test('13 个英文简称两两不同且符合乐理记法', () {
      expect(AppIntervalPalette.shorthands, <String>[
        'P1', 'm2', 'M2', 'm3', 'M3', 'P4', 'TT', 'P5', 'm6', 'M6', 'm7', 'M7',
        'P8',
      ]);
      expect(AppIntervalPalette.shorthands.toSet().length, 13);
    });

    test('三全音使用唯一的六边形 glyph', () {
      expect(AppIntervalPalette.light.glyphOf(6), IntervalGlyph.hexagon);
      expect(
        AppIntervalPalette.glyphs.where((IntervalGlyph g) => g == IntervalGlyph.hexagon).length,
        1,
      );
    });

    test('小六度（H=111，绿）标记为与 success 语义色冲突', () {
      for (int n = 0; n <= AppIntervalPalette.maxSemitones; n++) {
        expect(
          AppIntervalPalette.light.conflictsWithSuccess(n),
          n == 8,
          reason: 'semitones=$n',
        );
      }
    });
  });

  group('查表 API', () {
    test('colorOf / glyphOf / shorthandOf 对越界输入 clamp 到 [0, 12]', () {
      const AppIntervalPalette p = AppIntervalPalette.light;
      expect(p.colorOf(-5), p.colorOf(0));
      expect(p.colorOf(99), p.colorOf(12));
      expect(p.glyphOf(-1), p.glyphOf(0));
      expect(p.glyphOf(13), p.glyphOf(12));
      expect(p.shorthandOf(-1), 'P1');
      expect(p.shorthandOf(13), 'P8');
    });

    test('of(brightness) 返回对应板', () {
      expect(AppIntervalPalette.of(Brightness.light), AppIntervalPalette.light);
      expect(AppIntervalPalette.of(Brightness.dark), AppIntervalPalette.dark);
    });

    test('colors 长度恒为 13', () {
      expect(AppIntervalPalette.light.colors.length, 13);
      expect(AppIntervalPalette.dark.colors.length, 13);
    });
  });

  group('ThemeExtension 契约', () {
    test('copyWith 不传参返回等价对象', () {
      expect(AppIntervalPalette.light.copyWith(), AppIntervalPalette.light);
    });

    test('copyWith 传入新色板生效', () {
      final AppIntervalPalette custom = AppIntervalPalette.light.copyWith(
        colors: AppIntervalPalette.dark.colors,
      );
      expect(custom.colors, AppIntervalPalette.dark.colors);
    });

    test('lerp 端点精确，中点逐色插值', () {
      const AppIntervalPalette a = AppIntervalPalette.light;
      const AppIntervalPalette b = AppIntervalPalette.dark;
      expect(a.lerp(b, 0.0).colors, a.colors);
      expect(a.lerp(b, 1.0).colors, b.colors);
      final AppIntervalPalette mid = a.lerp(b, 0.5);
      for (int n = 0; n <= 12; n++) {
        expect(mid.colorOf(n), Color.lerp(a.colorOf(n), b.colorOf(n), 0.5));
      }
      expect(a.lerp(null, 0.5), a);
    });

    test('相等性基于内容而非引用', () {
      final AppIntervalPalette copy = AppIntervalPalette(
        colors: List<Color>.of(AppIntervalPalette.light.colors),
      );
      expect(copy, AppIntervalPalette.light);
      expect(copy.hashCode, AppIntervalPalette.light.hashCode);
      expect(copy, isNot(AppIntervalPalette.dark));
    });
  });
}
