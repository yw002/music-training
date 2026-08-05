import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/elevation_tokens.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 卡片尺寸档：普通卡 20 圆角 / 20 内边距；大卡 28 圆角 / 24 内边距。
enum AppCardSize {
  /// 普通卡片。
  normal,

  /// 首页大卡、报告 KPI 卡。
  large,
}

/// 通用卡片容器。
///
/// 深浅主题的海拔策略差异（浅色彩色阴影 vs 深色内描边）已经在
/// `AppElevations` 里抹平，这里只需要选一个海拔档位。
///
/// 可点击时带 `M-12 answer.hover` 的悬停提升，桌面端才可见。
class AppCard extends StatefulWidget {
  /// 创建卡片。
  const AppCard({
    required this.child,
    this.size = AppCardSize.normal,
    this.elevation = 2,
    this.hoverElevation = 3,
    this.onTap,
    this.gradient,
    this.padding,
    this.clip = true,
    this.semanticLabel,
    super.key,
  });

  /// 卡片内容。
  final Widget child;

  /// 尺寸档。
  final AppCardSize size;

  /// 默认海拔（0..5）。
  final int elevation;

  /// 悬停海拔（0..5）；仅在 [onTap] 非空时生效。
  final int hoverElevation;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 覆盖背景为渐变（如首页「今日练习」大卡）。
  final Gradient? gradient;

  /// 覆盖内边距。
  final EdgeInsetsGeometry? padding;

  /// 是否裁剪子内容到圆角。
  final bool clip;

  /// 无障碍标签。
  final String? semanticLabel;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered != value && mounted) {
      setState(() => _hovered = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool interactive = widget.onTap != null;
    final int level = interactive && _hovered
        ? widget.hoverElevation
        : widget.elevation;
    final AppElevationStyle style = tokens.elevation.level(level);
    final BorderRadius radius = widget.size == AppCardSize.large
        ? tokens.radius.bigCard
        : tokens.radius.card;
    final EdgeInsetsGeometry padding = widget.padding ??
        (widget.size == AppCardSize.large
            ? tokens.space.bigCardInsets
            : tokens.space.cardInsets);

    Widget content = Padding(padding: padding, child: widget.child);
    if (widget.clip) {
      content = ClipRRect(borderRadius: radius, child: content);
    }

    final Widget card = AnimatedContainer(
      duration: context.mDur(tokens.motion.answer.hover.enter.duration), // M-12
      curve: tokens.motion.answer.hover.enter.curve,
      decoration: BoxDecoration(
        color: widget.gradient == null ? style.surface : null,
        gradient: widget.gradient,
        borderRadius: radius,
        boxShadow: style.shadows.isEmpty ? null : style.shadows,
        border: style.border,
      ),
      child: content,
    );

    if (!interactive) {
      return widget.semanticLabel == null
          ? card
          : Semantics(label: widget.semanticLabel, child: card);
    }

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: card,
        ),
      ),
    );
  }
}
