import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';

/// 首页快捷入口网格（T18）。
///
/// 把「自由训练 / 二选一 / 报告 / 设置 / 关于」等常用入口聚合成 2 列网格，
/// 每个入口只持有图标、标签与点击回调，便于测试用替身回调。
class QuickEntryGrid extends StatelessWidget {
  /// 创建快捷入口网格。
  const QuickEntryGrid({
    required this.onFree,
    required this.onBinary,
    required this.onReport,
    required this.onSettings,
    required this.onAbout,
    super.key,
  });

  /// 自由训练入口。
  final VoidCallback onFree;

  /// 二选一对比入口。
  final VoidCallback onBinary;

  /// 训练报告入口。
  final VoidCallback onReport;

  /// 设置入口。
  final VoidCallback onSettings;

  /// 关于入口。
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<_QuickEntry> entries = <_QuickEntry>[
      _QuickEntry(Icons.tune, AppStrings.home.freeTrainingEntry, onFree),
      _QuickEntry(
        Icons.compare_arrows,
        AppStrings.home.binaryTrainingEntry,
        onBinary,
      ),
      _QuickEntry(Icons.bar_chart, AppStrings.home.reportEntry, onReport),
      _QuickEntry(Icons.settings, AppStrings.settings.title, onSettings),
      _QuickEntry(Icons.info_outline, AppStrings.about.title, onAbout),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: tokens.space.sm,
      crossAxisSpacing: tokens.space.sm,
      childAspectRatio: 2.4,
      children: <Widget>[
        for (final _QuickEntry e in entries) _QuickEntryTile(entry: e),
      ],
    );
  }
}

class _QuickEntry {
  const _QuickEntry(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickEntryTile extends StatelessWidget {
  const _QuickEntryTile({required this.entry});
  final _QuickEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Card(
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.md),
          child: Row(
            children: <Widget>[
              Icon(entry.icon, color: tokens.scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(entry.label, style: tokens.type.bodyLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
