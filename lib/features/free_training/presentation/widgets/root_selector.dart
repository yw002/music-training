import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 根音范围选择（单选项：固定根音 / 有限随机 / 完全随机）。
class RootSelector extends StatelessWidget {
  /// 创建根音选择器。
  const RootSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 当前选中的根音策略。
  final RootMode value;

  /// 变更回调。
  final ValueChanged<RootMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    const strings = AppStrings.freeTraining;
    final List<(RootMode, String)> options = <(RootMode, String)>[
      (RootMode.fixed, strings.rootFixed),
      (RootMode.limitedRandom, strings.rootLimitedRandom),
      (RootMode.fullRandom, strings.rootFullRandom),
    ];
    return Wrap(
      spacing: tokens.space.xs,
      runSpacing: tokens.space.xs,
      children: <Widget>[
        for (final (RootMode mode, String label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == mode,
            onSelected: (_) => onChanged(mode), // M-29 chip.select
          ),
      ],
    );
  }
}
