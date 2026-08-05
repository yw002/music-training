import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/elevation_tokens.dart';
import 'package:interval_ear/app/theme/gradient_tokens.dart';
import 'package:interval_ear/app/theme/interval_palette.dart';
import 'package:interval_ear/app/theme/radius.dart';
import 'package:interval_ear/app/theme/semantic_colors.dart';
import 'package:interval_ear/app/theme/spacing.dart';
import 'package:interval_ear/app/theme/typography.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// Design Token 的**唯一访问入口**（架构 §8.3）。
///
/// 硬性规则（Code Review 必查）：
/// 1. 禁止 widget 中出现颜色字面量（`Color(0xFF...)`、`Colors.blue`）；
/// 2. 禁止 widget 中出现 `Duration(milliseconds: N)` 字面量；
/// 3. 禁止 widget 中出现间距魔法数字（`EdgeInsets.all(16)`）；
/// 4. 每个 motion token 的定义处必须注释对应的 `M-xx` 编号；
/// 5. 音程专属色只能通过 `tokens.interval.colorOf(...)` 取，且只在作答后使用。
extension AppTokensX on BuildContext {
  /// 取当前主题下的全部设计令牌。
  AppTokens get tokens => AppTokens._(this);
}

/// [AppTokensX.tokens] 返回的令牌集合。
@immutable
class AppTokens {
  const AppTokens._(this._context);

  final BuildContext _context;

  ThemeData get _theme => Theme.of(_context);

  /// Material 3 基础色板。
  ColorScheme get scheme => _theme.colorScheme;

  /// 语义色（success / warning / uncertain / 答案按钮 / 玻璃背板）。
  AppSemanticColors get color =>
      _theme.extension<AppSemanticColors>() ??
      AppSemanticColors.of(_theme.brightness);

  /// 渐变。
  AppGradients get gradient =>
      _theme.extension<AppGradients>() ?? AppGradients.of(_theme.brightness);

  /// 海拔与阴影。
  AppElevations get elevation =>
      _theme.extension<AppElevations>() ?? AppElevations.of(_theme.brightness);

  /// 13 音程标识色。
  AppIntervalPalette get interval =>
      _theme.extension<AppIntervalPalette>() ??
      AppIntervalPalette.of(_theme.brightness);

  /// 补充字号（答案按钮、数字）。
  AppTextExtras get text =>
      _theme.extension<AppTextExtras>() ?? AppTextExtras.standard();

  /// 动效时长与曲线（M-01…M-35）。
  AppMotionTokens get motion =>
      _theme.extension<AppMotionTokens>() ?? const AppMotionTokens.standard();

  /// Material `TextTheme`。
  TextTheme get type => _theme.textTheme;

  /// 间距（编译期常量，无主题依赖）。
  AppSpacing get space => AppSpacing.instance;

  /// 圆角（编译期常量，无主题依赖）。
  AppRadius get radius => AppRadius.instance;

  /// 当前是否深色主题。
  bool get isDark => _theme.brightness == Brightness.dark;
}
