import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';

/// 13 音程多选 chip（架构 §2.4 / T19 验收 ①）。
///
/// 至少选 2 个；二选一模式下 [maxSelectable] 为 2，达到上限后未选中的 chip 禁用，
/// 自然强制「binary 恰好 2 音程」。音程名一律来自 [IntervalCatalog]（领域数据），
/// 不在此硬编码。
class IntervalSelector extends StatelessWidget {
  /// 创建音程选择器。
  const IntervalSelector({
    required this.selected,
    required this.onToggle,
    this.maxSelectable,
    super.key,
  });

  /// 当前选中的音程集合。
  final Set<IntervalId> selected;

  /// 切换某个音程的回调。
  final ValueChanged<IntervalId> onToggle;

  /// 可选上限；为 `null` 时不限（自由训练模式）。
  final int? maxSelectable;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Set<IntervalId> ids = IntervalCatalog.trainableIds;
    return Wrap(
      spacing: tokens.space.xs,
      runSpacing: tokens.space.xs,
      children: <Widget>[
        for (final IntervalId id in ids)
          _IntervalChip(
            id: id,
            selected: selected.contains(id),
            disabled: !selected.contains(id) &&
                maxSelectable != null &&
                selected.length >= maxSelectable!,
            onToggle: onToggle,
          ),
      ],
    );
  }
}

class _IntervalChip extends StatelessWidget {
  const _IntervalChip({
    required this.id,
    required this.selected,
    required this.disabled,
    required this.onToggle,
  });

  final IntervalId id;
  final bool selected;
  final bool disabled;
  final ValueChanged<IntervalId> onToggle;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(IntervalCatalog.nameOf(id)),
      selected: selected,
      onSelected: disabled ? null : (_) => onToggle(id), // M-29 chip.select
    );
  }
}
