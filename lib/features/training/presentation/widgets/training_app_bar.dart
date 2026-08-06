import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/presentation/widgets/progress_bar.dart';

/// 训练页顶部栏（架构 §3.5 / T11）。
///
/// 左：标题 + 进度文案；中：进度条；右：连击标签（若有）+ 退出按钮。退出触发
/// [onAbort]（Cubit `abort()`），进度与连击文案由视图模型传入，本组件不读状态。
class TrainingAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// 创建训练页顶部栏。
  const TrainingAppBar({
    required this.title,
    required this.progressLabel,
    required this.progress,
    required this.comboLabel,
    required this.onAbort,
    super.key,
  });

  /// 标题。
  final String title;

  /// 进度文案（第 X / Y 题）。
  final String progressLabel;

  /// 进度 [0, 1]。
  final double progress;

  /// 连击文案（空表示无连击）。
  final String comboLabel;

  /// 退出回调。
  final VoidCallback onAbort;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppBar(
      backgroundColor: tokens.scheme.surface,
      foregroundColor: tokens.scheme.onSurface,
      elevation: 0,
      titleSpacing: tokens.space.md,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: tokens.type.titleMedium,
          ),
          SizedBox(height: tokens.space.xxs),
          Text(
            progressLabel,
            style: tokens.type.bodySmall
                ?.copyWith(color: tokens.scheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(6),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space.md),
          child: ProgressBar(value: progress),
        ),
      ),
      actions: <Widget>[
        if (comboLabel.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(right: tokens.space.sm),
            child: Chip(
              label: Text(comboLabel),
              backgroundColor: tokens.color.warning.container,
              labelStyle:
                  tokens.type.labelMedium?.copyWith(color: tokens.color.warning.onContainer),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: AppStrings.training.finishSession,
          onPressed: onAbort,
        ),
      ],
    );
  }
}
