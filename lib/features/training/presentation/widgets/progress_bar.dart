import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 训练进度条（`M-21` progress.bar：320ms standard）。
///
/// 进度变化用 [TweenAnimationBuilder] 过渡，时长经 `context.mDur` 折算当前动效档位；
/// `off` 档下时长归零直达终态（架构 §8.4）。颜色全部走 [AppTokens]，不出现颜色字面量。
class ProgressBar extends StatelessWidget {
  /// 创建进度条。
  const ProgressBar({
    required this.value,
    super.key,
  });

  /// 进度 [0, 1]。
  final double value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final clamped = value.clamp(0.0, 1.0);
    final duration = context.mDur(tokens.motion.progressBar.duration);
    return SizedBox(
      height: 6,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: clamped),
        duration: duration,
        curve: Curves.easeInOut,
        builder: (context, fraction, child) => ClipRRect(
          borderRadius: tokens.radius.pill,
          child: Container(
            height: 6,
            color: tokens.color.uncertain.container,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction,
              child: Container(color: tokens.scheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}
