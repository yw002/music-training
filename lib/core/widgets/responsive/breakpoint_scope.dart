import 'package:flutter/widgets.dart';

import 'package:interval_ear/app/theme/spacing.dart';

/// 响应式断点三档（PRD §6.1 / 架构 §1.4 T22）。
///
/// ```text
/// width  < 600            → compact
/// 600 <= width <= 1024    → medium
/// width  > 1024           → expanded
/// ```
///
/// **与 `AppBreakpoints` 的关系**：`app/theme/spacing.dart` 里的 [AppBreakpoints]
/// 是「页面水平内边距」的历史刻度（medium 600 / expanded 900），服务于
/// `AppSpacing.pageHorizontal`；本枚举是 **布局档位**（PRD §6.1 表），两者不是
/// 同一件事。新代码的布局分档一律以本枚举为准，内边距数值仍复用 [SpacingScale]
/// 常量，避免出现魔法数字。
///
/// 各字段取值直接对应 PRD §6.1 的适配表，此处即「响应式设计令牌」的定义处，
/// 业务 widget 一律通过 `context.breakpoint.*` 读取，禁止散落字面量。
enum Breakpoint {
  /// 手机竖屏：单列、全宽。
  compact(
    columns: 1,
    answerColumns: 2,
    contentMaxWidth: double.infinity,
    horizontalPadding: SpacingScale.pageHPaddingCompact,
    sidePanelWidth: 0,
  ),

  /// 平板 / 小窗：单列，内容 640 居中。
  medium(
    columns: 1,
    answerColumns: 3,
    contentMaxWidth: 640,
    horizontalPadding: SpacingScale.pageHPaddingMedium,
    sidePanelWidth: 0,
  ),

  /// 桌面宽窗：双列，内容 1080 居中，右侧栏 320。
  expanded(
    columns: 2,
    answerColumns: 3,
    contentMaxWidth: 1080,
    horizontalPadding: SpacingScale.pageHPaddingExpanded,
    sidePanelWidth: 320,
  );

  const Breakpoint({
    required this.columns,
    required this.answerColumns,
    required this.contentMaxWidth,
    required this.horizontalPadding,
    required this.sidePanelWidth,
  });

  /// medium 档下界（含）。
  static const double mediumMinWidth = 600;

  /// expanded 档下界（**不含**：`width > 1024` 才是 expanded）。
  static const double expandedMinWidth = 1024;

  /// 内容网格建议列数（compact/medium 单列，expanded 双列）。
  final int columns;

  /// 多选答案按钮列数（PRD §6.1：2 / 3 / 3）。
  final int answerColumns;

  /// 内容区最大宽度（compact 不限宽）。
  final double contentMaxWidth;

  /// 页面水平内边距（16 / 24 / 32）。
  final double horizontalPadding;

  /// 桌面右侧栏宽度（仅 expanded 非 0）。
  final double sidePanelWidth;

  /// 按窗口宽度判定档位（PRD §6.1）。
  static Breakpoint fromWidth(double width) {
    if (width < mediumMinWidth) {
      return Breakpoint.compact;
    }
    if (width <= expandedMinWidth) {
      return Breakpoint.medium;
    }
    return Breakpoint.expanded;
  }

  /// 是否 compact 档。
  bool get isCompact => this == Breakpoint.compact;

  /// 是否 medium 档。
  bool get isMedium => this == Breakpoint.medium;

  /// 是否 expanded 档。
  bool get isExpanded => this == Breakpoint.expanded;

  /// 是否 medium 及以上（常用于「非手机窄屏」的分支）。
  bool get isAtLeastMedium => this != Breakpoint.compact;

  /// 页面水平内边距（`EdgeInsets` 形式）。
  EdgeInsets get pageInsets =>
      EdgeInsets.symmetric(horizontal: horizontalPadding);
}

/// 向下广播当前 [Breakpoint] 的作用域。
///
/// 由 `ResponsiveBuilder` 挂载；组件通过 `context.breakpoint` 读取。未挂载时
/// [of] 会退化到 `MediaQuery.sizeOf(context).width` 现算，保证单独渲染某个组件
/// 的 widget test 不需要额外包一层（与 `MotionScopeData.fallback` 同口径）。
class BreakpointScope extends InheritedWidget {
  /// 创建断点作用域。
  const BreakpointScope({
    required this.breakpoint,
    required super.child,
    super.key,
  });

  /// 当前档位。
  final Breakpoint breakpoint;

  /// 读取最近的档位；未挂载时按 `MediaQuery` 宽度现算。
  static Breakpoint of(BuildContext context) =>
      maybeOf(context) ??
      Breakpoint.fromWidth(MediaQuery.sizeOf(context).width);

  /// 读取最近的档位；未挂载返回 `null`。
  static Breakpoint? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BreakpointScope>()
      ?.breakpoint;

  @override
  bool updateShouldNotify(BreakpointScope oldWidget) =>
      oldWidget.breakpoint != breakpoint;
}

/// 断点的 `BuildContext` 快捷读取入口。
///
/// **Flutter gotcha**：这些 getter 会建立 `InheritedWidget` 依赖，只能在
/// `build` / `didChangeDependencies` 中调用，**禁止在 `initState` 中读**。
extension BreakpointExtension on BuildContext {
  /// 当前断点档位。
  Breakpoint get breakpoint => BreakpointScope.of(this);

  /// 是否 compact 布局。
  bool get isCompactLayout => breakpoint.isCompact;

  /// 是否 expanded 布局。
  bool get isExpandedLayout => breakpoint.isExpanded;
}
