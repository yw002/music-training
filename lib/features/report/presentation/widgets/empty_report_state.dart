import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';

/// 报告空数据友好态（架构 §2.6 / T21 验收 ⑤）。
///
/// 零历史或尚未产生统计时展示，鼓励用户先完成几组训练，不抛不崩。
class EmptyReportState extends StatelessWidget {
  /// 创建空态。
  const EmptyReportState({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Center(
      child: Padding(
        padding: tokens.space.bigCardInsets,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.insights_rounded,
              size: 56,
              color: tokens.scheme.onSurfaceVariant,
            ),
            SizedBox(height: tokens.space.md),
            Text(
              AppStrings.report.notEnoughData,
              style: tokens.type.titleMedium
                  ?.copyWith(color: tokens.scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.space.xs),
            Text(
              AppStrings.report.emptyHint,
              style: tokens.type.bodySmall
                  ?.copyWith(color: tokens.scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
