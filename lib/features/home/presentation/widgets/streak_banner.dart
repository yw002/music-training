import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';

/// 连续练习天数横幅。
class StreakBanner extends StatelessWidget {
  /// 创建横幅。
  const StreakBanner({required this.days, super.key});

  /// 连续练习天数。
  final int days;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.md,
        vertical: tokens.space.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.color.warning.container,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.local_fire_department),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.home.streakDays(days),
              style: tokens.type.bodyMedium?.copyWith(
                color: tokens.color.warning.onContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
