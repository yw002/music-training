import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 播放方向选择（单选项：上行 / 下行 / 和声 / 随机混合）。
class DirectionSelector extends StatelessWidget {
  /// 创建方向选择器。
  const DirectionSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 当前选中的方向。
  final DirectionMode value;

  /// 变更回调。
  final ValueChanged<DirectionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    const strings = AppStrings.freeTraining;
    final List<(DirectionMode, String)> options = <(DirectionMode, String)>[
      (DirectionMode.ascending, strings.directionAscending),
      (DirectionMode.descending, strings.directionDescending),
      (DirectionMode.harmonic, strings.directionHarmonic),
      (DirectionMode.randomMixed, strings.directionRandomMixed),
    ];
    return Wrap(
      spacing: tokens.space.xs,
      runSpacing: tokens.space.xs,
      children: <Widget>[
        for (final (DirectionMode mode, String label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == mode,
            onSelected: (_) => onChanged(mode), // M-29 chip.select
          ),
      ],
    );
  }
}
