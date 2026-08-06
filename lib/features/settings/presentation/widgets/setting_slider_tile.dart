import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';

/// 通用滑块设置项。
class SettingSliderTile extends StatelessWidget {
  /// 创建设置滑块项。
  const SettingSliderTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.formatValue,
    super.key,
  });

  /// 标题。
  final String title;

  /// 副标题（可选）。
  final String? subtitle;

  /// 当前值。
  final double value;

  /// 最小值。
  final double min;

  /// 最大值。
  final double max;

  /// 离散档位数（为 `null` 时连续）。
  final int? divisions;

  /// 变更回调。
  final ValueChanged<double> onChanged;

  /// 把数值格式化为展示文案（默认取整）。
  final String Function(double value)? formatValue;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final String valueText =
        formatValue?.call(value) ?? value.toStringAsFixed(0);
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: tokens.space.md),
      title: Text(title, style: tokens.type.bodyLarge),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (subtitle != null)
            Text(
              subtitle!,
              style: tokens.type.bodySmall?.copyWith(
                color: tokens.scheme.onSurfaceVariant,
              ),
            ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueText,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
