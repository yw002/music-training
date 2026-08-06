import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';

/// 今日练习大卡（T18）。
class TodayCard extends StatelessWidget {
  /// 创建今日练习卡。
  const TodayCard({
    required this.config,
    required this.onStart,
    super.key,
  });

  /// 今日推荐配置（点击开始即带入训练页）。
  final TrainingConfig config;

  /// 点击「开始今日练习」。
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Card(
      child: Padding(
        padding: tokens.space.bigCardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(AppStrings.home.todayCardTitle, style: tokens.type.titleLarge),
            const SizedBox(height: 4),
            Text(
              AppStrings.home.todayCardSubtitle,
              style: tokens.type.bodyMedium?.copyWith(
                color: tokens.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: tokens.space.minTouchTarget + 8,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.scheme.primary,
                  foregroundColor: tokens.scheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radius.md),
                  ),
                ),
                child: Text(AppStrings.home.startTodayTraining),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
