import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';

/// 题目数量选择（固定 10 / 20 / 50，架构 §5 T19 验收 ①）。
class QuestionCountSelector extends StatelessWidget {
  /// 创建题数选择器。
  const QuestionCountSelector({
    required this.value,
    required this.onChanged,
    this.options = const <int>[10, 20, 50],
    super.key,
  });

  /// 当前题数。
  final int value;

  /// 变更回调。
  final ValueChanged<int> onChanged;

  /// 可选题数。
  final List<int> options;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Wrap(
      spacing: tokens.space.xs,
      runSpacing: tokens.space.xs,
      children: <Widget>[
        for (final int count in options)
          ChoiceChip(
            label: Text(AppStrings.unit.questions(count)),
            selected: value == count,
            onSelected: (_) => onChanged(count), // M-29 chip.select
          ),
      ],
    );
  }
}
