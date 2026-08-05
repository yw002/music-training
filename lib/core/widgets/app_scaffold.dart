import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/spacing.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 页面外壳。
///
/// 统一处理三件在每个页面都要做、做错就不一致的事：
/// 1. 响应式页面水平内边距（compact 16 / medium 24 / expanded 32）；
/// 2. `gradientAmbient` 整页背景 —— 仅首页与报告页允许开启（PRD §2.1.3），
///    且 `MotionLevel` 非 full 时自动退化为纯色，避免 ambient 流动动画；
/// 3. `SafeArea` 与 `AppBar` 的默认配置。
class AppScaffold extends StatelessWidget {
  /// 创建页面外壳。
  const AppScaffold({
    required this.body,
    this.title,
    this.titleWidget,
    this.actions = const <Widget>[],
    this.leading,
    this.showAmbientBackground = false,
    this.applyHorizontalPadding = true,
    this.bottomBar,
    this.floatingActionButton,
    this.scrollController,
    super.key,
  });

  /// 页面主体。
  final Widget body;

  /// AppBar 标题文字。
  final String? title;

  /// AppBar 标题自定义 Widget；优先级高于 [title]。
  final Widget? titleWidget;

  /// AppBar 右侧动作。
  final List<Widget> actions;

  /// AppBar 左侧控件。
  final Widget? leading;

  /// 是否铺 ambient 渐变背景（仅首页 / 报告页）。
  final bool showAmbientBackground;

  /// 是否自动套用响应式水平内边距。
  final bool applyHorizontalPadding;

  /// 底部固定栏。
  final Widget? bottomBar;

  /// 悬浮按钮。
  final Widget? floatingActionButton;

  /// 供上层监听滚动（玻璃顶栏需要）。
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final double width = MediaQuery.sizeOf(context).width;
    final bool ambient = showAmbientBackground && context.allowAmbient;

    Widget content = body;
    if (applyHorizontalPadding) {
      content = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space.pageHorizontal(width),
        ),
        child: content,
      );
    }

    final Widget? appBar = (title == null && titleWidget == null &&
            actions.isEmpty &&
            leading == null)
        ? null
        : AppBar(
            leading: leading,
            title: titleWidget ??
                (title == null
                    ? null
                    : Text(title!, style: tokens.type.titleLarge)),
            actions: actions,
          );

    return Scaffold(
      backgroundColor:
          ambient ? Colors.transparent : tokens.scheme.surface,
      appBar: appBar == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: appBar,
            ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ambient ? tokens.gradient.ambient : null,
          color: ambient ? null : tokens.scheme.surface,
        ),
        child: SafeArea(
          top: appBar == null,
          bottom: bottomBar == null,
          child: content,
        ),
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.space.pageHorizontal(width),
                  SpacingScale.xs,
                  tokens.space.pageHorizontal(width),
                  SpacingScale.md,
                ),
                child: bottomBar,
              ),
            ),
      floatingActionButton: floatingActionButton,
    );
  }
}
