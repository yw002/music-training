import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/semantic_colors.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 横幅语气。
enum WarningBannerTone {
  /// 提示信息（中立）。
  info,

  /// 警告（音频不可用、存储写失败等可恢复问题）。
  warning,

  /// 错误（功能不可用）。
  error,
}

/// 常驻警示横幅。
///
/// 与 Snackbar 的分工：Snackbar 是**瞬时**反馈，本组件用于**持续存在**的状态
/// （例如「音频引擎不可用，训练已暂停」「设置保存失败，已连续 3 次」）。
///
/// 展开 / 收起走 `M-16 feedback.wrong` 的 220ms standard，`reduced` 档位下
/// 由 `context.mDur` 自动压到 150ms，`off` 档位下瞬时切换。
class WarningBanner extends StatelessWidget {
  /// 创建横幅。
  const WarningBanner({
    required this.message,
    this.tone = WarningBannerTone.warning,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.visible = true,
    super.key,
  });

  /// 主文案。
  final String message;

  /// 语气。
  final WarningBannerTone tone;

  /// 操作按钮文案。
  final String? actionLabel;

  /// 操作回调。
  final VoidCallback? onAction;

  /// 关闭回调；为空时不显示关闭按钮。
  final VoidCallback? onDismiss;

  /// 是否可见。为 `false` 时高度收为 0（带动画）。
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final _BannerPalette palette = _paletteFor(tokens, tone);

    return AnimatedSize(
      duration: context.mDur(tokens.motion.feedback.wrong.duration), // M-16
      curve: tokens.motion.feedback.wrong.curve,
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              label: message,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(tokens.space.sm),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: tokens.radius.card,
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(palette.icon, size: 20, color: palette.foreground),
                    SizedBox(width: tokens.space.xs),
                    Expanded(
                      child: Text(
                        message,
                        style: tokens.type.bodyMedium?.copyWith(
                          color: palette.foreground,
                        ),
                      ),
                    ),
                    if (actionLabel != null) ...<Widget>[
                      SizedBox(width: tokens.space.xs),
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.foreground,
                          minimumSize: Size.zero,
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.space.xs,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(actionLabel!),
                      ),
                    ],
                    if (onDismiss != null)
                      IconButton(
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close, size: 18),
                        color: palette.foreground,
                        tooltip: AppStrings.common.close,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  _BannerPalette _paletteFor(AppTokens tokens, WarningBannerTone tone) {
    final AppSemanticColors color = tokens.color;
    return switch (tone) {
      WarningBannerTone.info => _BannerPalette(
          background: color.uncertain.container,
          foreground: color.uncertain.onContainer,
          border: color.uncertain.base,
          icon: Icons.info_outline,
        ),
      WarningBannerTone.warning => _BannerPalette(
          background: color.warning.container,
          foreground: color.warning.onContainer,
          border: color.warning.base,
          icon: Icons.warning_amber_outlined,
        ),
      WarningBannerTone.error => _BannerPalette(
          background: tokens.scheme.errorContainer,
          foreground: tokens.scheme.onErrorContainer,
          border: tokens.scheme.error,
          icon: Icons.error_outline,
        ),
    };
  }
}

@immutable
class _BannerPalette {
  const _BannerPalette({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;
}
