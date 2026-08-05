import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// 通用 chip / 标签。
///
/// 承载 `M-29 chip.select`：选中 160ms standard，回弹 180ms overshoot。
/// 可选 [leadingColor] 用于音程标识色 —— 注意 PRD §2.2.1，展示音程时必须同时
/// 给出半音数数字（由调用方放进 [trailingLabel]），仅靠颜色不合规。
class AppChip extends StatelessWidget {
  /// 创建 chip。
  const AppChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.leadingColor,
    this.leadingIcon,
    this.trailingLabel,
    this.semanticLabel,
    super.key,
  });

  /// 主文字。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 点击回调；为 `null` 时为纯展示标签。
  final VoidCallback? onTap;

  /// 前置圆点色（音程标识色等）。
  final Color? leadingColor;

  /// 前置图标；与 [leadingColor] 二选一。
  final IconData? leadingIcon;

  /// 尾部小字（半音数、计数等），使用 tabular 数字字号。
  final String? trailingLabel;

  /// 无障碍标签。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final MotionPairSpec select = tokens.motion.common.chipSelect; // M-29
    final MotionSpec spec = selected ? select.enter : select.exit;
    final bool animated = context.motionLevel == MotionLevel.full;

    final Color background =
        selected ? tokens.color.answerSurfaceSelected : tokens.elevation.e1.surface;
    final Color foreground =
        selected ? tokens.scheme.onPrimaryContainer : tokens.scheme.onSurface;

    final Widget chip = AnimatedContainer(
      duration: context.mDur(spec.duration),
      curve: spec.curve,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.sm,
        vertical: tokens.space.xxs,
      ),
      constraints: BoxConstraints(minHeight: tokens.space.xl),
      decoration: BoxDecoration(
        color: background,
        borderRadius: tokens.radius.pill,
        border: Border.all(
          color: selected ? tokens.scheme.primary : tokens.scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leadingColor != null) ...<Widget>[
            AnimatedScale(
              scale: selected && animated ? 1.15 : 1.0,
              duration: context.mDur(spec.duration),
              curve: spec.curve,
              child: Container(
                width: tokens.space.sm,
                height: tokens.space.sm,
                decoration: BoxDecoration(
                  color: leadingColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: tokens.space.xs),
          ] else if (leadingIcon != null) ...<Widget>[
            Icon(leadingIcon, size: 16, color: foreground),
            SizedBox(width: tokens.space.xs),
          ],
          Text(
            label,
            style: tokens.type.labelLarge?.copyWith(color: foreground),
          ),
          if (trailingLabel != null) ...<Widget>[
            SizedBox(width: tokens.space.xs),
            Text(
              trailingLabel!,
              style: tokens.text.numericSmall.copyWith(
                color: tokens.scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(label: semanticLabel ?? label, child: chip);
    }
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: chip,
        ),
      ),
    );
  }
}
