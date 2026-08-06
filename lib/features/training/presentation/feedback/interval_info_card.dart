import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';

/// 答案信息卡（架构 §3.5 / T13）。
///
/// 清晰呈现「正确答案」与「你的答案」两个标签 + 音程名。颜色走语义色（success /
/// warning），不引入英文简称强制显示——口径与设置页 `showIntervalShorthand` 解耦，
/// 反馈区始终给出完整中文名以保证教学明确。
class IntervalInfoCard extends StatelessWidget {
  /// 创建答案信息卡。
  const IntervalInfoCard({
    required this.correctInterval,
    required this.selectedInterval,
    required this.isUncertain,
    super.key,
  });

  /// 正确音程。
  final IntervalId correctInterval;

  /// 用户所选音程（不确定为 `null`）。
  final IntervalId? selectedInterval;

  /// 是否标记为不确定。
  final bool isUncertain;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final correctName = IntervalCatalog.nameOf(correctInterval);
    final IntervalId? sel = selectedInterval;
    final selectedName = isUncertain
        ? AppStrings.feedback.uncertain
        : (sel == null ? AppStrings.common.empty : IntervalCatalog.nameOf(sel));
    final selectedColor = isUncertain
        ? tokens.color.uncertain.base
        : (selectedInterval == correctInterval
            ? tokens.color.success.base
            : tokens.color.warning.base);

    return Row(
      children: <Widget>[
        Expanded(
          child: _Cell(
            label: AppStrings.feedback.correctAnswer,
            name: correctName,
            color: tokens.color.success.base,
            background: tokens.color.success.container,
          ),
        ),
        SizedBox(width: tokens.space.sm),
        Expanded(
          child: _Cell(
            label: AppStrings.feedback.yourAnswer,
            name: selectedName,
            color: selectedColor,
            background: isUncertain
                ? tokens.color.uncertain.container
                : (selectedInterval == correctInterval
                    ? tokens.color.success.container
                    : tokens.color.warning.container),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.name,
    required this.color,
    required this.background,
  });

  final String label;
  final String name;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(tokens.space.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: tokens.type.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: tokens.space.xxs),
          Text(
            name,
            style: tokens.type.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
