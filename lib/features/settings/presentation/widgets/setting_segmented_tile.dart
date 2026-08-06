import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';

/// 单选项（键值对），用于 [SettingSegmentedTile]。
class SegmentOption<T> {
  /// 创建一个选项。
  const SegmentOption({required this.value, required this.label});

  /// 选项值。
  final T value;

  /// 选项展示文案。
  final String label;
}

/// 通用分段选择设置项（Material 3 [SegmentedButton]，竖直排版避免窄屏溢出）。
class SettingSegmentedTile<T> extends StatelessWidget {
  /// 创建设置分段项。
  const SettingSegmentedTile({
    required this.title,
    this.subtitle,
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 标题。
  final String title;

  /// 副标题（可选）。
  final String? subtitle;

  /// 全部可选项。
  final List<SegmentOption<T>> options;

  /// 当前选中的值。
  final T value;

  /// 变更回调。
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.space.md,
        vertical: tokens.space.xs,
      ),
      title: Text(title, style: tokens.type.bodyLarge),
      subtitle: Padding(
        padding: EdgeInsets.only(top: tokens.space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (subtitle != null)
              Text(
                subtitle!,
                style: tokens.type.bodySmall?.copyWith(
                  color: tokens.scheme.onSurfaceVariant,
                ),
              ),
            SegmentedButton<T>(
              selected: <T>{value},
              onSelectionChanged: (Set<T> selected) {
                if (selected.isNotEmpty) {
                  onChanged(selected.first);
                }
              },
              segments: <ButtonSegment<T>>[
                for (final SegmentOption<T> option in options)
                  ButtonSegment<T>(
                    value: option.value,
                    label: Text(option.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
