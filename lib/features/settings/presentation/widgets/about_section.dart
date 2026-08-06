import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/constants/app_strings.dart';

/// 关于区块（关于页 / 设置页共用）：版本号、简介、数据存储说明。
class AboutSection extends StatelessWidget {
  /// 创建关于区块。
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.about.version(AppConfig.appVersion),
          style: tokens.type.titleMedium,
        ),
        SizedBox(height: tokens.space.sm),
        Text(
          AppStrings.about.intro,
          style: tokens.type.bodyMedium?.copyWith(
            color: tokens.scheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: tokens.space.sm),
        Text(
          AppStrings.about.storageNotice,
          style: tokens.type.bodySmall?.copyWith(
            color: tokens.scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
