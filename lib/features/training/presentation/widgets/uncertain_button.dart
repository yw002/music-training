import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';

/// 「不确定」作答按钮（架构 §3.5 / T11）。
///
/// 中性反馈专用按钮：点选后不计入错误猜测、不清零连击（[TrainingAttempt] 语义）。
/// 仅在等待作答时可用，其余阶段禁用（走 `M-14` 变灰）。
class UncertainButton extends StatelessWidget {
  /// 创建「不确定」按钮。
  const UncertainButton({
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  /// 点击回调。
  final VoidCallback? onPressed;

  /// 是否可用。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final canPress = enabled && onPressed != null;
    return Semantics(
      label: AppStrings.training.uncertain,
      button: true,
      enabled: canPress,
      child: SizedBox(
        width: double.infinity,
        height: tokens.space.minTouchTarget,
        child: OutlinedButton(
          onPressed: canPress ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.color.uncertain.base,
            side: BorderSide(color: tokens.color.uncertain.base),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radius.md),
            ),
          ),
          child: Text(AppStrings.training.uncertain),
        ),
      ),
    );
  }
}
