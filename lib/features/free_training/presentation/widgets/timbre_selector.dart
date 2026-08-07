import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 音色选择（单选项：合成键盘 / 合成拨弦）。
class TimbreSelector extends StatelessWidget {
  /// 创建音色选择器。
  const TimbreSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 当前选中的音色策略。
  final TimbreMode value;

  /// 变更回调。
  final ValueChanged<TimbreMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    const strings = AppStrings.freeTraining;
    final List<(TimbreMode, String)> options = <(TimbreMode, String)>[
      (TimbreMode.keyboard, strings.timbreKeyboard),
      (TimbreMode.plucked, strings.timbrePlucked),
    ];
    return Wrap(
      spacing: tokens.space.xs,
      runSpacing: tokens.space.xs,
      children: <Widget>[
        for (final (TimbreMode mode, String label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == mode,
            onSelected: (_) => onChanged(mode), // M-29 chip.select
          ),
      ],
    );
  }
}
