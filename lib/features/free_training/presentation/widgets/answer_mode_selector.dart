import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 答题模式选择（单选项：全部音程 / 仅所选音程 / 二选一）。
class AnswerModeSelector extends StatelessWidget {
  /// 创建答题模式选择器。
  const AnswerModeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 当前答题模式。
  final AnswerMode value;

  /// 变更回调。
  final ValueChanged<AnswerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    const strings = AppStrings.freeTraining;
    final List<(AnswerMode, String)> options = <(AnswerMode, String)>[
      (AnswerMode.allIntervals, strings.answerModeAll),
      (AnswerMode.enabledOnly, strings.answerModeEnabled),
      (AnswerMode.binary, strings.answerModeBinary),
    ];
    return Wrap(
      spacing: tokens.space.xs,
      runSpacing: tokens.space.xs,
      children: <Widget>[
        for (final (AnswerMode mode, String label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == mode,
            onSelected: (_) => onChanged(mode), // M-29 chip.select
          ),
      ],
    );
  }
}
