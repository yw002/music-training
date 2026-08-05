import 'package:flutter/material.dart';

/// 渐变 token（PRD §2.1.3）。
///
/// 硬性禁止（写在这里便于 Code Review 对照）：
/// - 正文文字使用渐变；
/// - 答案按钮默认态使用渐变（会干扰对错反馈的颜色语义）；
/// - 同屏出现 3 个以上渐变面。
@immutable
class AppGradients extends ThemeExtension<AppGradients> {
  /// 创建渐变扩展。
  const AppGradients({
    required this.brand,
    required this.energy,
    required this.calm,
    required this.ambient,
  });

  /// 主 CTA、进度条填充、交替对比播放按钮。
  final LinearGradient brand;

  /// 首页「今日练习」大卡。
  final LinearGradient energy;

  /// 报告页 KPI 卡、趋势图面积。
  final LinearGradient calm;

  /// 首页 / 报告页整页背景（仅这两处）。
  final RadialGradient ambient;

  /// `gradientBrand`：topLeft → bottomRight，`#6C5BFF → #B44BE8`。
  static const LinearGradient _brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF6C5BFF), Color(0xFFB44BE8)],
  );

  /// `gradientEnergy`：135°，`#FF6B9D → #FF9F6B`。
  static const LinearGradient _energy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF6B9D), Color(0xFFFF9F6B)],
  );

  /// `gradientCalm`：135°，`#00B8A9 → #2E7DF7`。
  static const LinearGradient _calm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF00B8A9), Color(0xFF2E7DF7)],
  );

  /// 浅色主题渐变组。
  static const AppGradients light = AppGradients(
    brand: _brand,
    energy: _energy,
    calm: _calm,
    ambient: RadialGradient(
      center: Alignment(0, -0.9),
      radius: 1.1,
      colors: <Color>[Color(0xFFEDE9FF), Color(0xFFFCFBFF)],
      stops: <double>[0, 0.75],
    ),
  );

  /// 深色主题渐变组。
  static const AppGradients dark = AppGradients(
    brand: _brand,
    energy: _energy,
    calm: _calm,
    ambient: RadialGradient(
      center: Alignment(0, -0.9),
      radius: 1.1,
      colors: <Color>[Color(0xFF241A5C), Color(0xFF0F0E13)],
      stops: <double>[0, 0.75],
    ),
  );

  /// 按亮度取渐变组。
  static AppGradients of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  @override
  AppGradients copyWith({
    LinearGradient? brand,
    LinearGradient? energy,
    LinearGradient? calm,
    RadialGradient? ambient,
  }) =>
      AppGradients(
        brand: brand ?? this.brand,
        energy: energy ?? this.energy,
        calm: calm ?? this.calm,
        ambient: ambient ?? this.ambient,
      );

  @override
  AppGradients lerp(covariant ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) {
      return this;
    }
    return AppGradients(
      brand: LinearGradient.lerp(brand, other.brand, t)!,
      energy: LinearGradient.lerp(energy, other.energy, t)!,
      calm: LinearGradient.lerp(calm, other.calm, t)!,
      ambient: RadialGradient.lerp(ambient, other.ambient, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppGradients &&
          other.brand == brand &&
          other.energy == energy &&
          other.calm == calm &&
          other.ambient == ambient;

  @override
  int get hashCode => Object.hash(brand, energy, calm, ambient);
}
