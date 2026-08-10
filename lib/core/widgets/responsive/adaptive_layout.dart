import 'dart:async';

import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/curves.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';
import 'package:interval_ear/core/platform/platform_capabilities.dart';
import 'package:interval_ear/core/widgets/responsive/breakpoint_scope.dart';

/// `M-33` tooltip 的缩放起点（PRD §3.x：`fade + scale 0.94→1.0`）。
const double _kTooltipScaleBegin = 0.94;

/// 按断点收敛内容宽度的布局容器（架构 §1.4 T22）。
///
/// PRD §6.1「内容最大宽度」：compact 全宽 / medium 640 居中 / expanded 1080 居中。
/// 只做「限宽 + 居中（+ 可选水平内边距）」这一件事，**不重排**子树，符合 §8.3
/// 最小变更原则：页面把既有 `ListView` 原样塞进来即可获得三档适配。
///
/// **约束**：本 widget 依赖父级提供有界高度（典型用法是直接放在 `Scaffold.body`
/// 里包住滚动视图）。不要把它当作 `ListView` 的子项使用。
class AdaptiveLayout extends StatelessWidget {
  /// 创建自适应布局容器。
  const AdaptiveLayout({
    required this.child,
    this.maxWidth,
    this.applyHorizontalPadding = false,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  /// 内容子树。
  final Widget child;

  /// 覆盖断点默认的最大宽度；留空取 `Breakpoint.contentMaxWidth`。
  final double? maxWidth;

  /// 是否顺带套用断点对应的页面水平内边距（16 / 24 / 32）。
  ///
  /// 默认 `false`：既有页面大多已自行调用 `tokens.space.pageInsets`，重复套用会
  /// 导致内边距翻倍。
  final bool applyHorizontalPadding;

  /// 限宽后的对齐方式。
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final Breakpoint breakpoint = context.breakpoint;
    final double limit = maxWidth ?? breakpoint.contentMaxWidth;

    Widget content = child;
    if (applyHorizontalPadding) {
      content = Padding(padding: breakpoint.pageInsets, child: content);
    }
    if (!limit.isFinite) {
      return content;
    }
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit),
        child: content,
      ),
    );
  }
}

/// 按断点切换列数的等宽网格（compact 单列 / expanded 多列）。
///
/// 用 `Wrap` + 显式子项宽度实现，而非 `GridView` 的 `childAspectRatio`：后者在
/// 窄屏 + 大字号下极易把子项压出 `RenderFlex overflow`（T22 验收 ①②）。
///
/// 需要有界宽度；父级宽度无界时自动退化为单列。
class AdaptiveGrid extends StatelessWidget {
  /// 创建自适应网格。
  const AdaptiveGrid({
    required this.children,
    this.columns,
    this.spacing,
    super.key,
  });

  /// 网格项。
  final List<Widget> children;

  /// 覆盖断点默认列数；留空取 `Breakpoint.columns`。
  final int? columns;

  /// 行列间距；留空取 `tokens.space.cardGap`。
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final double gap = spacing ?? context.tokens.space.cardGap;
    final int requested = columns ?? context.breakpoint.columns;
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    if (requested <= 1) {
      return _singleColumn(gap);
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth) {
          return _singleColumn(gap);
        }
        final int count = requested;
        final double itemWidth =
            (constraints.maxWidth - gap * (count - 1)) / count;
        if (itemWidth <= 0) {
          return _singleColumn(gap);
        }
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Widget item in children)
              SizedBox(width: itemWidth, child: item),
          ],
        );
      },
    );
  }

  Widget _singleColumn(double gap) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(SizedBox(height: gap));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

/// 仅桌面显示的 tooltip（`M-33`：hover 停留 500ms 后 fade + scale 0.94→1.0，140ms）。
///
/// - 移动端（无窗口装饰 / 无指针 hover）直接返回子树，不挂任何监听；
/// - 时长与延迟全部取自 `context.tokens.motion.common`，不写 `Duration` 字面量；
/// - 受 `MotionLevel` 影响：`off` 档 `context.mDur` 折算为 0，直接闪现终态
///   （架构 §8.4：低档位跳过过程但必须到达终态）。
///
/// 之所以不直接用 Material `Tooltip`：它的淡入时长写死在框架内部（150ms），
/// 无法对齐 `M-33` 的 140ms 令牌。
class AdaptiveTooltip extends StatefulWidget {
  /// 创建桌面 tooltip。
  const AdaptiveTooltip({
    required this.message,
    required this.child,
    this.enabled = true,
    super.key,
  });

  /// 提示文案（须来自 `AppStrings`）。
  final String message;

  /// 被包裹的子树。
  final Widget child;

  /// 是否启用（业务侧可临时关掉）。
  final bool enabled;

  @override
  State<AdaptiveTooltip> createState() => _AdaptiveTooltipState();
}

class _AdaptiveTooltipState extends State<AdaptiveTooltip>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  late final AnimationController _fade;
  late final Animation<double> _scale;
  Timer? _timer;
  Duration _delay = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Flutter gotcha：时长依赖 context.tokens（Theme.of），initState 里读不到，
    // 这里先建零时长控制器，真正的时长在 didChangeDependencies 赋值。
    _fade = AnimationController(vsync: this, duration: Duration.zero);
    _scale = Tween<double>(begin: _kTooltipScaleBegin, end: 1).animate(
      CurvedAnimation(parent: _fade, curve: AppCurve.standard),
    );
    _fade.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final CommonMotionTokens common = context.tokens.motion.common;
    // M-33：hover 停留 500ms 才出现；淡入 140ms standard。
    _delay = common.tooltipDelay;
    _fade.duration = context.mDur(common.tooltipFade.duration);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _portal.isShowing) {
      _portal.hide();
    }
  }

  bool get _isDesktop => PlatformCapabilities.current.hasWindowChrome;

  void _scheduleShow() {
    if (!widget.enabled || !_isDesktop) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(_delay, () {
      if (!mounted) {
        return;
      }
      if (!_portal.isShowing) {
        _portal.show();
      }
      _fade.forward();
    });
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    _fade.reverse();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.removeStatusListener(_onStatus);
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_isDesktop) {
      return widget.child;
    }
    final AppTokens tokens = context.tokens;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (BuildContext overlayContext) => Positioned.fill(
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
              offset: Offset(0, tokens.space.xs),
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: _TooltipBubble(message: widget.message),
                ),
              ),
            ),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          onEnter: (_) => _scheduleShow(),
          onExit: (_) => _hide(),
          child: widget.child,
        ),
      ),
    );
  }
}

/// tooltip 气泡本体。
class _TooltipBubble extends StatelessWidget {
  const _TooltipBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Breakpoint.medium.contentMaxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.scheme.inverseSurface,
            borderRadius: BorderRadius.circular(tokens.radius.sm),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space.sm,
              vertical: tokens.space.xs,
            ),
            child: Text(
              message,
              style: tokens.type.bodySmall?.copyWith(
                color: tokens.scheme.onInverseSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
