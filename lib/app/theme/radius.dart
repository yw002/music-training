import 'package:flutter/widgets.dart';

/// 圆角原始刻度（PRD §2.5）。
///
/// 提供**编译期常量**，供 `const` 上下文使用。
abstract final class RadiusScale {
  /// 6
  static const double xs = 6;

  /// 10
  static const double sm = 10;

  /// 14
  static const double md = 14;

  /// 20
  static const double lg = 20;

  /// 28
  static const double xl = 28;

  /// 36
  static const double xxl = 36;

  /// 999（胶囊）
  static const double full = 999;
}

/// 圆角体系（PRD §2.5）。
///
/// 不随主题变化，走编译期常量。统一入口：`context.tokens.radius`。
@immutable
class AppRadius {
  const AppRadius._();

  /// 全局唯一实例。
  static const AppRadius instance = AppRadius._();

  /// 6
  double get xs => RadiusScale.xs;

  /// 10
  double get sm => RadiusScale.sm;

  /// 14
  double get md => RadiusScale.md;

  /// 20
  double get lg => RadiusScale.lg;

  /// 28
  double get xl => RadiusScale.xl;

  /// 36
  double get xxl => RadiusScale.xxl;

  /// 999
  double get full => RadiusScale.full;

  /// 普通卡片 20。
  BorderRadius get card => BorderRadius.circular(RadiusScale.lg);

  /// 首页大卡 / 报告 KPI 卡 28。
  BorderRadius get bigCard => BorderRadius.circular(RadiusScale.xl);

  /// 多选答案按钮 20。
  BorderRadius get answerButton => BorderRadius.circular(RadiusScale.lg);

  /// 二选一大按钮 24。
  BorderRadius get binaryButton => BorderRadius.circular(24);

  /// 通用按钮 20（与多选答案按钮同规格）。
  BorderRadius get button => BorderRadius.circular(RadiusScale.lg);

  /// Chip / 标签 / 进度条：胶囊。
  BorderRadius get pill => BorderRadius.circular(RadiusScale.full);

  /// 底部面板顶部 28（仅左上、右上）。
  BorderRadius get bottomSheet => const BorderRadius.only(
        topLeft: Radius.circular(RadiusScale.xl),
        topRight: Radius.circular(RadiusScale.xl),
      );

  /// 对话框 28。
  BorderRadius get dialog => BorderRadius.circular(RadiusScale.xl);

  /// 输入框 / 下拉 14。
  BorderRadius get field => BorderRadius.circular(RadiusScale.md);

  /// 图表柱条顶部 6。
  BorderRadius get chartBar => const BorderRadius.only(
        topLeft: Radius.circular(RadiusScale.xs),
        topRight: Radius.circular(RadiusScale.xs),
      );

  /// 任意值的圆角。
  BorderRadius all(double value) => BorderRadius.circular(value);
}
