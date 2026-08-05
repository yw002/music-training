import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// 按钮视觉变体。
enum AppButtonVariant {
  /// 主 CTA：品牌渐变填充（PRD §2.1.3 `gradientBrand` 的合法用途）。
  primary,

  /// 次级：主色容器填充。
  tonal,

  /// 描边。
  outlined,

  /// 纯文字。
  text,

  /// 危险操作：error 色填充。
  destructive,
}

/// 通用按钮。
///
/// 统一承载 `M-11 answer.press` 的按下反馈（90ms 按下 / 160ms overshoot 回弹），
/// 并严格遵守架构 §8.3：不出现颜色 / 时长 / 间距字面量，全部走 `context.tokens`。
///
/// 无障碍：最小触控目标 48×48；`Semantics` 标签取 [label]；`reduced/off` 档位下
/// 缩放反馈自动降级为不缩放（时长为 0 时 `AnimatedScale` 直接跳终值）。
class AppButton extends StatefulWidget {
  /// 创建按钮。
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.minHeight,
    this.semanticLabel,
    super.key,
  });

  /// 按钮文字。
  final String label;

  /// 点击回调；为 `null` 时按钮禁用。
  final VoidCallback? onPressed;

  /// 视觉变体。
  final AppButtonVariant variant;

  /// 前置图标。
  final IconData? icon;

  /// 是否横向撑满父容器。
  final bool expand;

  /// 覆盖最小高度；默认 48。
  final double? minHeight;

  /// 无障碍标签；默认取 [label]。
  final String? semanticLabel;

  /// 是否可用。
  bool get enabled => onPressed != null;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  void _setHovered(bool value) {
    if (_hovered != value && mounted) {
      setState(() => _hovered = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final MotionPairSpec press = tokens.motion.answer.press; // M-11
    final MotionLevel level = context.motionLevel;
    final bool enabled = widget.enabled;

    final _ButtonPalette palette = _paletteFor(tokens, widget.variant, enabled);
    final double scale = _pressed && level == MotionLevel.full ? 0.97 : 1.0;

    final Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          Icon(widget.icon, size: 20, color: palette.foreground),
          SizedBox(width: tokens.space.xs),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.type.labelLarge?.copyWith(color: palette.foreground),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: scale,
            duration: context
                .mDur(_pressed ? press.enter.duration : press.exit.duration),
            curve: _pressed ? press.enter.curve : press.exit.curve,
            child: AnimatedContainer(
              duration: context.mDur(tokens.motion.answer.hover.enter.duration),
              curve: tokens.motion.answer.hover.enter.curve, // M-12
              constraints: BoxConstraints(
                minHeight: widget.minHeight ?? tokens.space.minTouchTarget,
                minWidth: tokens.space.minTouchTarget,
              ),
              width: widget.expand ? double.infinity : null,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space.lg,
                vertical: tokens.space.sm,
              ),
              decoration: BoxDecoration(
                color: palette.gradient == null
                    ? (_hovered && enabled
                        ? palette.hoverBackground
                        : palette.background)
                    : null,
                gradient: palette.gradient,
                borderRadius: tokens.radius.button,
                border: palette.border,
                boxShadow: palette.gradient != null && enabled
                    ? tokens.elevation.e2.shadows
                    : null,
              ),
              child: Center(
                widthFactor: widget.expand ? null : 1,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ButtonPalette _paletteFor(
    AppTokens tokens,
    AppButtonVariant variant,
    bool enabled,
  ) {
    final ColorScheme scheme = tokens.scheme;
    if (!enabled) {
      // M-14：禁用态统一走 12% / 38% 的 Material 规范值。
      return _ButtonPalette(
        background: scheme.onSurface.withValues(alpha: 0.12),
        hoverBackground: scheme.onSurface.withValues(alpha: 0.12),
        foreground: scheme.onSurface.withValues(alpha: 0.38),
      );
    }
    return switch (variant) {
      AppButtonVariant.primary => _ButtonPalette(
          background: scheme.primary,
          hoverBackground: scheme.primary,
          foreground: scheme.onPrimary,
          gradient: tokens.gradient.brand,
        ),
      AppButtonVariant.tonal => _ButtonPalette(
          background: scheme.primaryContainer,
          hoverBackground: scheme.secondaryContainer,
          foreground: scheme.onPrimaryContainer,
        ),
      AppButtonVariant.outlined => _ButtonPalette(
          background: Colors.transparent,
          hoverBackground: scheme.surfaceContainerHigh,
          foreground: scheme.primary,
          border: Border.all(color: scheme.outline),
        ),
      AppButtonVariant.text => _ButtonPalette(
          background: Colors.transparent,
          hoverBackground: scheme.surfaceContainerHigh,
          foreground: scheme.primary,
        ),
      AppButtonVariant.destructive => _ButtonPalette(
          background: scheme.error,
          hoverBackground: scheme.error,
          foreground: scheme.onError,
        ),
    };
  }
}

@immutable
class _ButtonPalette {
  const _ButtonPalette({
    required this.background,
    required this.hoverBackground,
    required this.foreground,
    this.gradient,
    this.border,
  });

  final Color background;
  final Color hoverBackground;
  final Color foreground;
  final Gradient? gradient;
  final BoxBorder? border;
}
