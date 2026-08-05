import 'package:flutter/widgets.dart';

/// 间距原始刻度（PRD §2.4）。
///
/// 提供**编译期常量**，供 `const` 上下文（如 widget 构造函数默认值）使用。
/// 业务 widget 内请优先使用 `context.tokens.space.*`。
abstract final class SpacingScale {
  /// 4
  static const double xxs = 4;

  /// 8
  static const double xs = 8;

  /// 12
  static const double sm = 12;

  /// 16
  static const double md = 16;

  /// 24
  static const double lg = 24;

  /// 32
  static const double xl = 32;

  /// 48
  static const double xxl = 48;

  /// 64
  static const double xxxl = 64;

  /// 页面水平内边距 · compact。
  static const double pageHPaddingCompact = 16;

  /// 页面水平内边距 · medium。
  static const double pageHPaddingMedium = 24;

  /// 页面水平内边距 · expanded。
  static const double pageHPaddingExpanded = 32;

  /// 普通卡片内边距。
  static const double cardPadding = 20;

  /// 大卡内边距。
  static const double bigCardPadding = 24;

  /// 卡片之间垂直间距。
  static const double cardGap = 16;

  /// 分区之间垂直间距。
  static const double sectionGap = 32;

  /// 答案按钮网格 gap · compact。
  static const double answerGridGapCompact = 12;

  /// 答案按钮网格 gap · medium 及以上。
  static const double answerGridGapMedium = 16;

  /// 触控目标最小边长（iOS 44 亦满足）。
  static const double minTouchTarget = 48;

  /// 二选一大按钮最小高度。
  static const double binaryButtonMinHeight = 140;
}

/// 间距体系（PRD §2.4）。
///
/// 不随主题变化，因此不放进 `ThemeExtension`，走编译期常量更省。
/// 统一入口：`context.tokens.space`。
@immutable
class AppSpacing {
  const AppSpacing._();

  /// 全局唯一实例。
  static const AppSpacing instance = AppSpacing._();

  /// 4
  double get xxs => SpacingScale.xxs;

  /// 8
  double get xs => SpacingScale.xs;

  /// 12
  double get sm => SpacingScale.sm;

  /// 16
  double get md => SpacingScale.md;

  /// 24
  double get lg => SpacingScale.lg;

  /// 32
  double get xl => SpacingScale.xl;

  /// 48
  double get xxl => SpacingScale.xxl;

  /// 64
  double get xxxl => SpacingScale.xxxl;

  /// 普通卡片内边距 20。
  double get cardPadding => SpacingScale.cardPadding;

  /// 大卡内边距 24。
  double get bigCardPadding => SpacingScale.bigCardPadding;

  /// 卡片之间垂直间距 16。
  double get cardGap => SpacingScale.cardGap;

  /// 分区之间垂直间距 32。
  double get sectionGap => SpacingScale.sectionGap;

  /// 触控目标最小边长 48。
  double get minTouchTarget => SpacingScale.minTouchTarget;

  /// 二选一大按钮最小高度 140。
  double get binaryButtonMinHeight => SpacingScale.binaryButtonMinHeight;

  /// 按窗口宽度返回页面水平内边距。
  double pageHorizontal(double width) {
    if (width >= AppBreakpoints.expanded) {
      return SpacingScale.pageHPaddingExpanded;
    }
    if (width >= AppBreakpoints.medium) {
      return SpacingScale.pageHPaddingMedium;
    }
    return SpacingScale.pageHPaddingCompact;
  }

  /// 按窗口宽度返回答案按钮网格 gap。
  double answerGridGap(double width) => width >= AppBreakpoints.medium
      ? SpacingScale.answerGridGapMedium
      : SpacingScale.answerGridGapCompact;

  /// 页面水平内边距（`EdgeInsets` 形式）。
  EdgeInsets pageInsets(double width) =>
      EdgeInsets.symmetric(horizontal: pageHorizontal(width));

  /// 普通卡片内边距（`EdgeInsets` 形式）。
  EdgeInsets get cardInsets => const EdgeInsets.all(SpacingScale.cardPadding);

  /// 大卡内边距（`EdgeInsets` 形式）。
  EdgeInsets get bigCardInsets =>
      const EdgeInsets.all(SpacingScale.bigCardPadding);
}

/// 响应式断点（架构 §1.7：编译期常量类）。
abstract final class AppBreakpoints {
  /// compact 上界 / medium 下界。
  static const double medium = 600;

  /// medium 上界 / expanded 下界。
  static const double expanded = 900;

  /// 超宽（桌面双栏）下界。
  static const double large = 1240;

  /// 是否 compact 布局。
  static bool isCompact(double width) => width < medium;

  /// 是否 medium 布局。
  static bool isMedium(double width) => width >= medium && width < expanded;

  /// 是否 expanded 及以上布局。
  static bool isExpanded(double width) => width >= expanded;
}
