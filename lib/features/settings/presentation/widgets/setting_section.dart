import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';

/// 设置分区容器：分区标题 + 卡片化的子项列表（子项之间用分隔线）。
class SettingSection extends StatelessWidget {
  /// 创建设置分区。
  const SettingSection({
    required this.title,
    this.subtitle,
    required this.children,
    super.key,
  });

  /// 分区标题。
  final String title;

  /// 分区副标题（可选）。
  final String? subtitle;

  /// 分区内的设置项（通常为 ListTile / SwitchListTile）。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space.md,
            vertical: tokens.space.xs,
          ),
          child: Text(
            title,
            style: tokens.type.titleSmall?.copyWith(
              color: tokens.scheme.primary,
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: EdgeInsets.only(
              left: tokens.space.md,
              right: tokens.space.md,
              bottom: tokens.space.xs,
            ),
            child: Text(
              subtitle!,
              style: tokens.type.bodySmall?.copyWith(
                color: tokens.scheme.onSurfaceVariant,
              ),
            ),
          ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
