import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/constants/app_strings.dart';

/// 关于页（T17 / `about` 路由）。
class AboutPage extends StatelessWidget {
  /// 创建关于页。
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.about.title)),
      body: ListView(
        padding: tokens.space.pageInsets(width).copyWith(
              top: tokens.space.lg,
              bottom: tokens.space.xl,
            ),
        children: <Widget>[
          Text(
            AppStrings.about.version(AppConfig.appVersion),
            style: tokens.type.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(AppStrings.about.intro, style: tokens.type.bodyMedium),
          const SizedBox(height: 12),
          Text(
            AppStrings.about.storageNotice,
            style: tokens.type.bodySmall,
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(AppStrings.about.licenses),
            onTap: () => showLicensePage(context: context),
          ),
        ],
      ),
    );
  }
}
