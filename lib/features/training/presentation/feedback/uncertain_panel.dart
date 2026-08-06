import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/training/presentation/feedback/feedback_tokens.dart';

/// 「不确定」反馈面板（架构 §3.5 / T13，`M-20` feedback.uncertain）。
///
/// 用户主动标记「没听出来」时的中性反馈：不判对错、不清零连击、不出现警示红。
/// 用 `uncertain` 语义色给出平静的提示，强调「这很正常，多听几遍」。时长走 M-20，
/// 经 `context.mDur` 折算当前档位。
class UncertainPanel extends StatelessWidget {
  /// 创建不确定面板。
  const UncertainPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final duration = context.mDur(FeedbackTokens.uncertain);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, value, _) => Opacity(
        opacity: value,
        child: Container(
          margin: EdgeInsets.only(top: tokens.space.md),
          padding: tokens.space.cardInsets,
          decoration: BoxDecoration(
            color: tokens.color.uncertain.container,
            borderRadius: tokens.radius.card,
            border: Border.all(color: tokens.color.uncertain.base),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.help_outline_rounded, color: tokens.color.uncertain.base),
              SizedBox(width: tokens.space.sm),
              Expanded(
                child: Text(
                  AppStrings.feedback.uncertain,
                  style: tokens.type.bodyMedium
                      ?.copyWith(color: tokens.color.uncertain.onContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
