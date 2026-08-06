import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';

/// 通用开关设置项。
class SettingSwitchTile extends StatelessWidget {
  /// 创建设置开关项。
  const SettingSwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  /// 标题。
  final String title;

  /// 副标题（可选）。
  final String? subtitle;

  /// 当前开关值。
  final bool value;

  /// 变更回调（为 `null` 时禁用）。
  final ValueChanged<bool>? onChanged;

  /// 无障碍语义标签（可选）。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final SwitchListTile tile = SwitchListTile(
      title: Text(title, style: tokens.type.bodyLarge),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: tokens.type.bodySmall?.copyWith(
                color: tokens.scheme.onSurfaceVariant,
              ),
            ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.space.md,
        vertical: tokens.space.xs,
      ),
      shape: RoundedRectangleBorder(borderRadius: tokens.radius.card),
    );
    if (semanticLabel == null) {
      return tile;
    }
    return Semantics(label: semanticLabel, child: tile);
  }
}
