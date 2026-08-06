import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/presentation/feedback/feedback_controller.dart';

/// 交替对比（A/B）播放按钮（`M-19` compare.abButton）。
///
/// 通过 [FeedbackHandle] 触发一次对比播放（正确音程 vs 你所选）。播放中显示旋转
/// 进度环并禁用，避免重复触发（[FeedbackController] 内部单缓冲保证只播一次）。
/// 时长由音频序列长度驱动，这里只负责「状态指示」。
class ABCompareButton extends StatelessWidget {
  /// 创建 A/B 对比按钮。
  const ABCompareButton({
    required this.handle,
    super.key,
  });

  /// 反馈控制器句柄。
  final FeedbackHandle handle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final comparing = handle.isComparing;
    return SizedBox(
      height: tokens.space.minTouchTarget,
      child: OutlinedButton.icon(
        onPressed: comparing ? null : handle.playComparison,
        icon: comparing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.scheme.primary,
                ),
              )
            : const Icon(Icons.compare_arrows_rounded),
        label: Text(AppStrings.training.compareAb),
      ),
    );
  }
}
