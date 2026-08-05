import 'package:flutter/material.dart';

/// 一组语义色的三件套：基色 / 容器 / 容器上前景。
@immutable
class SemanticColorRole {
  /// 创建语义色三件套。
  const SemanticColorRole({
    required this.base,
    required this.on,
    required this.container,
    required this.onContainer,
  });

  /// 基色（用于图标、描边、进度条）。
  final Color base;

  /// 基色之上的前景色。
  final Color on;

  /// 容器底色。
  final Color container;

  /// 容器之上的前景色（正文级对比度已校验 ≥ 4.5:1）。
  final Color onContainer;

  /// 线性插值。
  static SemanticColorRole lerp(
    SemanticColorRole a,
    SemanticColorRole b,
    double t,
  ) =>
      SemanticColorRole(
        base: Color.lerp(a.base, b.base, t)!,
        on: Color.lerp(a.on, b.on, t)!,
        container: Color.lerp(a.container, b.container, t)!,
        onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SemanticColorRole &&
          other.base == base &&
          other.on == on &&
          other.container == container &&
          other.onContainer == onContainer);

  @override
  int get hashCode => Object.hash(base, on, container, onContainer);
}

/// 语义色扩展（PRD §2.1 语义色 + §2.7 玻璃拟态参数）。
///
/// Material 3 的 `ColorScheme` 只覆盖 error，`success / warning / uncertain`
/// 以及答案按钮、玻璃背板等业务语义色通过本扩展注入。
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  /// 创建语义色扩展。
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.uncertain,
    required this.answerSurface,
    required this.answerSurfaceHover,
    required this.answerSurfaceSelected,
    required this.answerBorder,
    required this.glassSurface,
    required this.glassBorder,
    required this.glassBlurSigma,
    required this.scrimOpacity,
    required this.glowOpacity,
  });

  /// 正确 / 达成。
  final SemanticColorRole success;

  /// 警告 / 需注意。
  final SemanticColorRole warning;

  /// 中立 / 不确定（未作答、数据不足）。
  final SemanticColorRole uncertain;

  /// 答案按钮默认底。
  final Color answerSurface;

  /// 答案按钮 hover 底。
  final Color answerSurfaceHover;

  /// 答案按钮选中底。
  final Color answerSurfaceSelected;

  /// 答案按钮描边。
  final Color answerBorder;

  /// 玻璃背板底色（已含不透明度）。
  final Color glassSurface;

  /// 玻璃背板内描边。
  final Color glassBorder;

  /// 玻璃模糊 sigma（PRD §2.7：桌面 20，移动 16，降级 0）。
  final double glassBlurSigma;

  /// 遮罩不透明度（浅 32% / 深 56%）。
  final double scrimOpacity;

  /// 发光不透明度（PRD §2.6：45%）。
  final double glowOpacity;

  /// 浅色语义色（PRD §2.1.1 语义色扩展表）。
  static const AppSemanticColors light = AppSemanticColors(
    success: SemanticColorRole(
      // 对比度修正：原 #0E9F5B on #FFF 仅 3.43:1，压深至 5.06:1。
      base: Color(0xFF0B7F49),
      on: Color(0xFFFFFFFF),
      container: Color(0xFFCFF5E1),
      onContainer: Color(0xFF04482B),
    ),
    warning: SemanticColorRole(
      // 对比度修正：原 #D97706 on #FFF 仅 3.19:1，压深至 5.00:1。
      base: Color(0xFFA85C05),
      on: Color(0xFFFFFFFF),
      container: Color(0xFFFDEEC8),
      onContainer: Color(0xFF5C2A05),
    ),
    uncertain: SemanticColorRole(
      base: Color(0xFF6B7684),
      on: Color(0xFFFFFFFF),
      container: Color(0xFFE1E7EE),
      onContainer: Color(0xFF28313A),
    ),
    answerSurface: Color(0xFFEAE7F1),
    answerSurfaceHover: Color(0xFFE4E1EC),
    answerSurfaceSelected: Color(0xFFE4E0FF),
    answerBorder: Color(0xFFC8C5D0),
    glassSurface: Color(0xB8FCFBFF),
    glassBorder: Color(0x66FFFFFF),
    glassBlurSigma: 20,
    scrimOpacity: 0.32,
    glowOpacity: 0.45,
  );

  /// 深色语义色（PRD §2.1.2 语义色扩展表）。
  static const AppSemanticColors dark = AppSemanticColors(
    success: SemanticColorRole(
      base: Color(0xFF3DDC84),
      on: Color(0xFF04482B),
      container: Color(0xFF04482B),
      onContainer: Color(0xFFCFF5E1),
    ),
    warning: SemanticColorRole(
      base: Color(0xFFFDB022),
      on: Color(0xFF5C2A05),
      container: Color(0xFF5C2A05),
      onContainer: Color(0xFFFDEEC8),
    ),
    uncertain: SemanticColorRole(
      base: Color(0xFF9AA5B1),
      on: Color(0xFF28313A),
      container: Color(0xFF28313A),
      onContainer: Color(0xFFE1E7EE),
    ),
    answerSurface: Color(0xFF26242D),
    answerSurfaceHover: Color(0xFF312F38),
    answerSurfaceSelected: Color(0xFF4235C4),
    answerBorder: Color(0xFF47464F),
    glassSurface: Color(0x991B1A22),
    glassBorder: Color(0x14FFFFFF),
    glassBlurSigma: 20,
    scrimOpacity: 0.56,
    glowOpacity: 0.45,
  );

  /// 按亮度取语义色。
  static AppSemanticColors of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  @override
  AppSemanticColors copyWith({
    SemanticColorRole? success,
    SemanticColorRole? warning,
    SemanticColorRole? uncertain,
    Color? answerSurface,
    Color? answerSurfaceHover,
    Color? answerSurfaceSelected,
    Color? answerBorder,
    Color? glassSurface,
    Color? glassBorder,
    double? glassBlurSigma,
    double? scrimOpacity,
    double? glowOpacity,
  }) =>
      AppSemanticColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        uncertain: uncertain ?? this.uncertain,
        answerSurface: answerSurface ?? this.answerSurface,
        answerSurfaceHover: answerSurfaceHover ?? this.answerSurfaceHover,
        answerSurfaceSelected:
            answerSurfaceSelected ?? this.answerSurfaceSelected,
        answerBorder: answerBorder ?? this.answerBorder,
        glassSurface: glassSurface ?? this.glassSurface,
        glassBorder: glassBorder ?? this.glassBorder,
        glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
        scrimOpacity: scrimOpacity ?? this.scrimOpacity,
        glowOpacity: glowOpacity ?? this.glowOpacity,
      );

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      success: SemanticColorRole.lerp(success, other.success, t),
      warning: SemanticColorRole.lerp(warning, other.warning, t),
      uncertain: SemanticColorRole.lerp(uncertain, other.uncertain, t),
      answerSurface: Color.lerp(answerSurface, other.answerSurface, t)!,
      answerSurfaceHover:
          Color.lerp(answerSurfaceHover, other.answerSurfaceHover, t)!,
      answerSurfaceSelected:
          Color.lerp(answerSurfaceSelected, other.answerSurfaceSelected, t)!,
      answerBorder: Color.lerp(answerBorder, other.answerBorder, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassBlurSigma:
          _lerpDouble(glassBlurSigma, other.glassBlurSigma, t),
      scrimOpacity: _lerpDouble(scrimOpacity, other.scrimOpacity, t),
      glowOpacity: _lerpDouble(glowOpacity, other.glowOpacity, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSemanticColors &&
          other.success == success &&
          other.warning == warning &&
          other.uncertain == uncertain &&
          other.answerSurface == answerSurface &&
          other.answerSurfaceHover == answerSurfaceHover &&
          other.answerSurfaceSelected == answerSurfaceSelected &&
          other.answerBorder == answerBorder &&
          other.glassSurface == glassSurface &&
          other.glassBorder == glassBorder &&
          other.glassBlurSigma == glassBlurSigma &&
          other.scrimOpacity == scrimOpacity &&
          other.glowOpacity == glowOpacity;

  @override
  int get hashCode => Object.hash(
        success,
        warning,
        uncertain,
        answerSurface,
        answerSurfaceHover,
        answerSurfaceSelected,
        answerBorder,
        glassSurface,
        glassBorder,
        glassBlurSigma,
        scrimOpacity,
        glowOpacity,
      );
}
