import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 单档海拔的完整视觉描述（PRD §2.6）。
///
/// 浅色主题走「彩色柔和阴影」；深色主题走「1px 内描边 + 表面提亮（+ 外阴影）」。
/// 两套策略被统一成同一个结构，业务侧只需 `elevation.e2` 即可，无需判断主题。
@immutable
class AppElevationStyle {
  /// 创建海拔样式。
  const AppElevationStyle({
    required this.surface,
    this.shadows = const <BoxShadow>[],
    this.borderColor,
    this.borderWidth = 1,
  });

  /// 该海拔对应的表面色。
  final Color surface;

  /// 外阴影列表（浅色为彩色柔和阴影；深色仅 e3+ 有）。
  final List<BoxShadow> shadows;

  /// 内描边颜色（深色主题专用；浅色为 `null`）。
  final Color? borderColor;

  /// 内描边宽度。
  final double borderWidth;

  /// 便捷生成 `Border`；无描边时返回 `null`。
  Border? get border => borderColor == null
      ? null
      : Border.all(color: borderColor!, width: borderWidth);

  /// 便捷生成卡片 `BoxDecoration`。
  BoxDecoration decoration({BorderRadiusGeometry? borderRadius}) =>
      BoxDecoration(
        color: surface,
        borderRadius: borderRadius,
        boxShadow: shadows.isEmpty ? null : shadows,
        border: border,
      );

  /// 线性插值。
  static AppElevationStyle lerp(
    AppElevationStyle a,
    AppElevationStyle b,
    double t,
  ) =>
      AppElevationStyle(
        surface: Color.lerp(a.surface, b.surface, t)!,
        shadows: BoxShadow.lerpList(a.shadows, b.shadows, t) ??
            const <BoxShadow>[],
        borderColor: Color.lerp(a.borderColor, b.borderColor, t),
        borderWidth: a.borderWidth + (b.borderWidth - a.borderWidth) * t,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppElevationStyle &&
          other.surface == surface &&
          other.borderColor == borderColor &&
          other.borderWidth == borderWidth &&
          listEquals(other.shadows, shadows));

  @override
  int get hashCode =>
      Object.hash(surface, borderColor, borderWidth, Object.hashAll(shadows));
}

/// 海拔与阴影扩展（PRD §2.6）。
@immutable
class AppElevations extends ThemeExtension<AppElevations> {
  /// 创建海拔扩展。
  const AppElevations({
    required this.e0,
    required this.e1,
    required this.e2,
    required this.e3,
    required this.e4,
    required this.e5,
  });

  /// 无海拔。
  final AppElevationStyle e0;

  /// 1 级。
  final AppElevationStyle e1;

  /// 2 级（卡片默认）。
  final AppElevationStyle e2;

  /// 3 级（浮层）。
  final AppElevationStyle e3;

  /// 4 级（底部面板）。
  final AppElevationStyle e4;

  /// 5 级（对话框）。
  final AppElevationStyle e5;

  /// 浅色海拔组：彩色柔和阴影（阴影基色为品牌主色 `#5B4BE0`，见 PRD §2.6）。
  static const AppElevations light = AppElevations(
    e0: AppElevationStyle(surface: Color(0xFFF6F3FC)),
    e1: AppElevationStyle(
      surface: Color(0xFFF0EDF7),
      shadows: <BoxShadow>[
        BoxShadow(
          color: Color(0x145B4BE0), // 8%
          offset: Offset(0, 2),
          blurRadius: 8,
        ),
      ],
    ),
    e2: AppElevationStyle(
      surface: Color(0xFFF0EDF7),
      shadows: <BoxShadow>[
        BoxShadow(
          color: Color(0x1A5B4BE0), // 10%
          offset: Offset(0, 4),
          blurRadius: 16,
        ),
      ],
    ),
    e3: AppElevationStyle(
      surface: Color(0xFFEAE7F1),
      shadows: <BoxShadow>[
        BoxShadow(
          color: Color(0x1F5B4BE0), // 12%
          offset: Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -2,
        ),
      ],
    ),
    e4: AppElevationStyle(
      surface: Color(0xFFEAE7F1),
      shadows: <BoxShadow>[
        BoxShadow(
          color: Color(0x245B4BE0), // 14%
          offset: Offset(0, 12),
          blurRadius: 32,
          spreadRadius: -4,
        ),
      ],
    ),
    e5: AppElevationStyle(
      surface: Color(0xFFE4E1EC),
      shadows: <BoxShadow>[
        BoxShadow(
          color: Color(0x295B4BE0), // 16%
          offset: Offset(0, 20),
          blurRadius: 48,
          spreadRadius: -8,
        ),
      ],
    ),
  );

  /// 深色海拔组：内描边 + 表面提亮（e3+ 追加外阴影）。
  static const AppElevations dark = AppElevations(
    e0: AppElevationStyle(surface: Color(0xFF17161D)),
    e1: AppElevationStyle(
      surface: Color(0xFF1B1A22),
      borderColor: Color(0x0FFFFFFF), // 6%
    ),
    e2: AppElevationStyle(
      surface: Color(0xFF26242D),
      borderColor: Color(0x14FFFFFF), // 8%
    ),
    e3: AppElevationStyle(
      surface: Color(0xFF26242D),
      borderColor: Color(0x1AFFFFFF), // 10%
      shadows: <BoxShadow>[
        BoxShadow(
          color: Color(0x66000000), // 40%
          offset: Offset(0, 8),
          blurRadius: 24,
        ),
      ],
    ),
    e4: AppElevationStyle(
      surface: Color(0xFF312F38),
      borderColor: Color(0x1FFFFFFF), // 12%
      shadows: <BoxShadow>[
        BoxShadow(
          color: Color(0x7A000000), // 48%
          offset: Offset(0, 12),
          blurRadius: 32,
        ),
      ],
    ),
    e5: AppElevationStyle(
      surface: Color(0xFF312F38),
      borderColor: Color(0x24FFFFFF), // 14%
      shadows: <BoxShadow>[
        BoxShadow(
          color: Color(0x8F000000), // 56%
          offset: Offset(0, 20),
          blurRadius: 48,
        ),
      ],
    ),
  );

  /// 按亮度取海拔组。
  static AppElevations of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  /// 按 0..5 取样式；越界时 clamp。
  AppElevationStyle level(int value) => switch (value.clamp(0, 5)) {
        0 => e0,
        1 => e1,
        2 => e2,
        3 => e3,
        4 => e4,
        _ => e5,
      };

  /// 发光效果（PRD §2.6：仅播放可视化与连击徽章，同屏最多 2 处）。
  static BoxShadow glow(Color color, {double opacity = 0.45}) => BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: 20,
      );

  @override
  AppElevations copyWith({
    AppElevationStyle? e0,
    AppElevationStyle? e1,
    AppElevationStyle? e2,
    AppElevationStyle? e3,
    AppElevationStyle? e4,
    AppElevationStyle? e5,
  }) =>
      AppElevations(
        e0: e0 ?? this.e0,
        e1: e1 ?? this.e1,
        e2: e2 ?? this.e2,
        e3: e3 ?? this.e3,
        e4: e4 ?? this.e4,
        e5: e5 ?? this.e5,
      );

  @override
  AppElevations lerp(covariant ThemeExtension<AppElevations>? other, double t) {
    if (other is! AppElevations) {
      return this;
    }
    return AppElevations(
      e0: AppElevationStyle.lerp(e0, other.e0, t),
      e1: AppElevationStyle.lerp(e1, other.e1, t),
      e2: AppElevationStyle.lerp(e2, other.e2, t),
      e3: AppElevationStyle.lerp(e3, other.e3, t),
      e4: AppElevationStyle.lerp(e4, other.e4, t),
      e5: AppElevationStyle.lerp(e5, other.e5, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppElevations &&
          other.e0 == e0 &&
          other.e1 == e1 &&
          other.e2 == e2 &&
          other.e3 == e3 &&
          other.e4 == e4 &&
          other.e5 == e5;

  @override
  int get hashCode => Object.hash(e0, e1, e2, e3, e4, e5);
}
