import 'package:flutter/material.dart';

/// 拉丁 / 数字字族。
///
/// **策略 B（PRD §0.3 决议）**：不内置 Inter 字体文件、不引 `google_fonts`，
/// 拉丁与数字直接走系统默认字族（`null` 表示交给平台），仅通过
/// [kTabularFigures] 强制等宽数字。等 Inter 子集资源就位后，把此常量改成
/// `'Inter'` 并在 `pubspec.yaml` 打开 `fonts:` 段即可，无需改任何调用点。
const String? kLatinFontFamily = null;

/// 中文与兜底字族链（PRD §2.3）。
///
/// iOS/macOS = PingFang SC，Android = Noto Sans CJK，Windows = 微软雅黑。
const List<String> kFontFamilyFallback = <String>[
  'PingFang SC',
  'Noto Sans CJK SC',
  'Source Han Sans SC',
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Segoe UI',
  'Roboto',
  'Helvetica Neue',
  'Arial',
];

/// 等宽数字特性。
///
/// **所有会变化的数字**（进度 8/20、计时、正确率、半音数、连击数）必须启用，
/// 防止字宽跳动导致布局抖动。
const List<FontFeature> kTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// 字体层级（PRD §2.3）。
///
/// 这里只定义「字形」，不带颜色；颜色由 `ThemeData` 依据 `ColorScheme` 套用。
abstract final class AppText {
  static TextStyle _style({
    required double size,
    required double height,
    required FontWeight weight,
    required double letterSpacing,
    bool tabular = false,
  }) =>
      TextStyle(
        fontFamily: kLatinFontFamily,
        fontFamilyFallback: kFontFamilyFallback,
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontFeatures: tabular ? kTabularFigures : null,
      );

  /// 57 / 1.12 / 700 / -0.25 —— 报告页首屏大数字。
  static final TextStyle displayLarge = _style(
    size: 57,
    height: 1.12,
    weight: FontWeight.w700,
    letterSpacing: -0.25,
  );

  /// 45 / 1.16 / 700 / 0 —— 结算页正确率。
  static final TextStyle displayMedium = _style(
    size: 45,
    height: 1.16,
    weight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// 36 / 1.22 / 700 / 0 —— 首页问候语。
  static final TextStyle displaySmall = _style(
    size: 36,
    height: 1.22,
    weight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// 32 / 1.25 / 600 / 0 —— 页面主标题。
  static final TextStyle headlineLarge = _style(
    size: 32,
    height: 1.25,
    weight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// 28 / 1.29 / 600 / 0 —— 错题面板标题。
  static final TextStyle headlineMedium = _style(
    size: 28,
    height: 1.29,
    weight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// 24 / 1.33 / 600 / 0 —— 卡片标题。
  static final TextStyle headlineSmall = _style(
    size: 24,
    height: 1.33,
    weight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// 22 / 1.27 / 600 / 0 —— AppBar 标题。
  static final TextStyle titleLarge = _style(
    size: 22,
    height: 1.27,
    weight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// 16 / 1.50 / 600 / +0.15 —— 分区标题。
  static final TextStyle titleMedium = _style(
    size: 16,
    height: 1.50,
    weight: FontWeight.w600,
    letterSpacing: 0.15,
  );

  /// 14 / 1.43 / 600 / +0.10 —— 列表项标题。
  static final TextStyle titleSmall = _style(
    size: 14,
    height: 1.43,
    weight: FontWeight.w600,
    letterSpacing: 0.10,
  );

  /// 16 / 1.50 / 400 / +0.50 —— 正文。
  static final TextStyle bodyLarge = _style(
    size: 16,
    height: 1.50,
    weight: FontWeight.w400,
    letterSpacing: 0.50,
  );

  /// 14 / 1.43 / 400 / +0.25 —— 次要正文。
  static final TextStyle bodyMedium = _style(
    size: 14,
    height: 1.43,
    weight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  /// 12 / 1.33 / 400 / +0.40 —— 辅助说明。
  static final TextStyle bodySmall = _style(
    size: 12,
    height: 1.33,
    weight: FontWeight.w400,
    letterSpacing: 0.40,
  );

  /// 14 / 1.43 / 600 / +0.10 —— 按钮文字。
  static final TextStyle labelLarge = _style(
    size: 14,
    height: 1.43,
    weight: FontWeight.w600,
    letterSpacing: 0.10,
  );

  /// 12 / 1.33 / 600 / +0.50 —— 角标、快捷键提示。
  static final TextStyle labelMedium = _style(
    size: 12,
    height: 1.33,
    weight: FontWeight.w600,
    letterSpacing: 0.50,
  );

  /// 11 / 1.45 / 600 / +0.50 —— 最小标注。
  static final TextStyle labelSmall = _style(
    size: 11,
    height: 1.45,
    weight: FontWeight.w600,
    letterSpacing: 0.50,
  );

  /// 20 / 1.20 / 600 / +0.20 —— 多选答案按钮。
  static final TextStyle answerButtonLabel = _style(
    size: 20,
    height: 1.20,
    weight: FontWeight.w600,
    letterSpacing: 0.20,
  );

  /// 26 / 1.15 / 700 / +0.20 —— 二选一大按钮。
  static final TextStyle answerButtonLabelXL = _style(
    size: 26,
    height: 1.15,
    weight: FontWeight.w700,
    letterSpacing: 0.20,
  );

  /// 48 / 1.10 / 700 / -1.00 —— 报告 KPI 数字（tabular）。
  static final TextStyle numericDisplay = _style(
    size: 48,
    height: 1.10,
    weight: FontWeight.w700,
    letterSpacing: -1.00,
    tabular: true,
  );

  /// 32 / 1.12 / 700 / -0.50 —— 连击数、结算数字（tabular）。
  static final TextStyle numericLarge = _style(
    size: 32,
    height: 1.12,
    weight: FontWeight.w700,
    letterSpacing: -0.50,
    tabular: true,
  );

  /// 18 / 1.20 / 600 / 0 —— 进度 8/20（tabular）。
  static final TextStyle numericMedium = _style(
    size: 18,
    height: 1.20,
    weight: FontWeight.w600,
    letterSpacing: 0,
    tabular: true,
  );

  /// 13 / 1.25 / 600 / 0 —— 半音数角标（tabular）。
  static final TextStyle numericSmall = _style(
    size: 13,
    height: 1.25,
    weight: FontWeight.w600,
    letterSpacing: 0,
    tabular: true,
  );

  /// 组装 Material 3 `TextTheme`。
  static TextTheme buildTextTheme() => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}

/// Material `TextTheme` 之外的补充字号（架构 §1.7 `AppTextExtras`）。
@immutable
class AppTextExtras extends ThemeExtension<AppTextExtras> {
  /// 创建补充字号扩展。
  const AppTextExtras({
    required this.answerButtonLabel,
    required this.answerButtonLabelXL,
    required this.numericDisplay,
    required this.numericLarge,
    required this.numericMedium,
    required this.numericSmall,
  });

  /// 多选答案按钮文字。
  final TextStyle answerButtonLabel;

  /// 二选一大按钮文字。
  final TextStyle answerButtonLabelXL;

  /// 报告 KPI 数字（tabular）。
  final TextStyle numericDisplay;

  /// 连击数、结算数字（tabular）。
  final TextStyle numericLarge;

  /// 进度 8/20（tabular）。
  final TextStyle numericMedium;

  /// 半音数角标（tabular）。
  final TextStyle numericSmall;

  /// 由 [AppText] 装配的标准实例。
  static AppTextExtras standard() => AppTextExtras(
        answerButtonLabel: AppText.answerButtonLabel,
        answerButtonLabelXL: AppText.answerButtonLabelXL,
        numericDisplay: AppText.numericDisplay,
        numericLarge: AppText.numericLarge,
        numericMedium: AppText.numericMedium,
        numericSmall: AppText.numericSmall,
      );

  @override
  AppTextExtras copyWith({
    TextStyle? answerButtonLabel,
    TextStyle? answerButtonLabelXL,
    TextStyle? numericDisplay,
    TextStyle? numericLarge,
    TextStyle? numericMedium,
    TextStyle? numericSmall,
  }) =>
      AppTextExtras(
        answerButtonLabel: answerButtonLabel ?? this.answerButtonLabel,
        answerButtonLabelXL: answerButtonLabelXL ?? this.answerButtonLabelXL,
        numericDisplay: numericDisplay ?? this.numericDisplay,
        numericLarge: numericLarge ?? this.numericLarge,
        numericMedium: numericMedium ?? this.numericMedium,
        numericSmall: numericSmall ?? this.numericSmall,
      );

  @override
  AppTextExtras lerp(
    covariant ThemeExtension<AppTextExtras>? other,
    double t,
  ) {
    if (other is! AppTextExtras) {
      return this;
    }
    return AppTextExtras(
      answerButtonLabel:
          TextStyle.lerp(answerButtonLabel, other.answerButtonLabel, t)!,
      answerButtonLabelXL:
          TextStyle.lerp(answerButtonLabelXL, other.answerButtonLabelXL, t)!,
      numericDisplay:
          TextStyle.lerp(numericDisplay, other.numericDisplay, t)!,
      numericLarge: TextStyle.lerp(numericLarge, other.numericLarge, t)!,
      numericMedium: TextStyle.lerp(numericMedium, other.numericMedium, t)!,
      numericSmall: TextStyle.lerp(numericSmall, other.numericSmall, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppTextExtras &&
          other.answerButtonLabel == answerButtonLabel &&
          other.answerButtonLabelXL == answerButtonLabelXL &&
          other.numericDisplay == numericDisplay &&
          other.numericLarge == numericLarge &&
          other.numericMedium == numericMedium &&
          other.numericSmall == numericSmall;

  @override
  int get hashCode => Object.hash(
        answerButtonLabel,
        answerButtonLabelXL,
        numericDisplay,
        numericLarge,
        numericMedium,
        numericSmall,
      );
}
