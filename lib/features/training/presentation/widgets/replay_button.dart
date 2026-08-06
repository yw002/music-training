import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';

/// 重播按钮（架构 §3.5 / T11）。
///
/// 仅当配置允许重播且处于「等待作答」阶段时可用；其余阶段禁用。图标 + 文案，
/// 最小触控目标 48。点击触发 [onPressed]（由 Cubit 调用 `replay()`）。
class ReplayButton extends StatelessWidget {
  /// 创建重播按钮。
  const ReplayButton({
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
      label: AppStrings.a11y.replayButton,
      button: true,
      enabled: canPress,
      child: SizedBox(
        height: tokens.space.minTouchTarget,
        child: TextButton.icon(
          onPressed: canPress ? onPressed : null,
          icon: const Icon(Icons.replay_rounded),
          label: Text(AppStrings.training.replay),
        ),
      ),
    );
  }
}
