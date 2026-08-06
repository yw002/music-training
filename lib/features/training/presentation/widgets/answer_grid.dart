import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/spacing.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_view_model.dart';
import 'package:interval_ear/features/training/presentation/widgets/answer_button.dart';

/// 答案按钮网格（架构 §3.5 / T11）。
///
/// 布局随窗口宽度响应式：compact 2 列、medium 及以上 3 列、启用可选英文简称时
/// 仍保持清晰。gap 取自 `context.tokens.space.answerGridGap`。网格顺序完全由
/// `options` 的半音数升序决定（[IntervalQuestion.answerOptions] 已保证），与
/// 正确答案无关——这是防位置泄露的关键。
class AnswerGrid extends StatelessWidget {
  /// 创建答案网格。
  const AnswerGrid({
    required this.options,
    required this.enabled,
    required this.onSelect,
    super.key,
  });

  /// 答案选项展示数据（按半音数升序）。
  final List<AnswerOptionView> options;

  /// 是否可作答。
  final bool enabled;

  /// 选中某音程的回调。
  final ValueChanged<IntervalId> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= AppBreakpoints.medium ? 3 : 2;
    final gap = tokens.space.answerGridGap(width);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: 2.4,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        return AnswerButton(
          option: option,
          enabled: enabled,
          onPressed: enabled ? () => onSelect(option.id) : null,
        );
      },
    );
  }
}
