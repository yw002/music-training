import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/semantic_colors.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_tokens.dart';

/// Snackbar 语气。
enum AppSnackBarTone {
  /// 中性信息。
  neutral,

  /// 成功。
  success,

  /// 警告。
  warning,

  /// 错误。
  error,
}

/// 统一的 Snackbar 入口（`M-31 snackbar`：280 进 / 停留 3000 / 200 出）。
///
/// 直接 `ScaffoldMessenger.of(context).showSnackBar(...)` 会绕过时长 token，
/// 因此所有提示都必须走这里。
abstract final class AppSnackBar {
  /// 展示一条 Snackbar。
  ///
  /// 返回 `ScaffoldMessenger` 的控制器，调用方可 `await closed` 等待关闭。
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    AppSnackBarTone tone = AppSnackBarTone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final AppTokens tokens = context.tokens;
    final MotionSequenceSpec spec = tokens.motion.common.snackbar; // M-31
    final _SnackPalette palette = _paletteFor(tokens, tone);

    final SnackBar snackBar = SnackBar(
      content: Row(
        children: <Widget>[
          Icon(palette.icon, color: palette.foreground, size: 20),
          SizedBox(width: tokens.space.sm),
          Expanded(
            child: Text(
              message,
              style: tokens.type.bodyMedium?.copyWith(
                color: palette.foreground,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: palette.background,
      duration: spec.hold,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(tokens.space.md),
      shape: RoundedRectangleBorder(borderRadius: tokens.radius.card),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: palette.actionForeground,
              onPressed: onAction ?? () {},
            ),
    );

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar();
    return messenger.showSnackBar(snackBar);
  }

  /// 展示一条错误提示，文案取自 [AppStrings.errors] 的调用方传入值。
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showError(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        context,
        message: message,
        tone: AppSnackBarTone.error,
        actionLabel: actionLabel ?? AppStrings.common.retry,
        onAction: onAction,
      );

  static _SnackPalette _paletteFor(AppTokens tokens, AppSnackBarTone tone) {
    final AppSemanticColors color = tokens.color;
    return switch (tone) {
      AppSnackBarTone.neutral => _SnackPalette(
          background: tokens.scheme.inverseSurface,
          foreground: tokens.scheme.onInverseSurface,
          actionForeground: tokens.scheme.inversePrimary,
          icon: Icons.info_outline,
        ),
      AppSnackBarTone.success => _SnackPalette(
          background: color.success.container,
          foreground: color.success.onContainer,
          actionForeground: color.success.onContainer,
          icon: Icons.check_circle_outline,
        ),
      AppSnackBarTone.warning => _SnackPalette(
          background: color.warning.container,
          foreground: color.warning.onContainer,
          actionForeground: color.warning.onContainer,
          icon: Icons.warning_amber_outlined,
        ),
      AppSnackBarTone.error => _SnackPalette(
          background: tokens.scheme.errorContainer,
          foreground: tokens.scheme.onErrorContainer,
          actionForeground: tokens.scheme.onErrorContainer,
          icon: Icons.error_outline,
        ),
    };
  }
}

@immutable
class _SnackPalette {
  const _SnackPalette({
    required this.background,
    required this.foreground,
    required this.actionForeground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color actionForeground;
  final IconData icon;
}
