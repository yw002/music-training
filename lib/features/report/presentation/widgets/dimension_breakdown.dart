import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/utils/math_utils.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/stats/accuracy_bucket.dart';
import 'package:interval_ear/features/training/domain/stats/dimension_statistics.dart';

/// 维度分解（方向 / 音色 / 根音，架构 §2.6 / T21 验收 ④）。
///
/// 把全局维度统计按三个维度分别列出正确率进度条，帮助定位「下行是否普遍比上行差」
/// 这类短板。文案复用设置页的同义标签（集中在 [AppStrings]）。
class DimensionBreakdown extends StatelessWidget {
  /// 创建维度分解。
  const DimensionBreakdown({required this.dimensions, super.key});

  /// 维度统计。
  final DimensionStatistics dimensions;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Card(
      child: Padding(
        padding: tokens.space.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _DimensionGroup(
              title: AppStrings.freeTraining.directionSection,
              entries: _directionEntries(),
            ),
            SizedBox(height: tokens.space.md),
            _DimensionGroup(
              title: AppStrings.freeTraining.timbreSection,
              entries: _timbreEntries(),
            ),
            SizedBox(height: tokens.space.md),
            _DimensionGroup(
              title: AppStrings.freeTraining.rootSection,
              entries: _rootEntries(),
            ),
          ],
        ),
      ),
    );
  }

  List<_DimEntry> _directionEntries() => <_DimEntry>[
        for (final PlaybackDirection d in PlaybackDirection.values)
          _DimEntry(_directionLabel(d), dimensions.directionBucket(d)),
      ];

  List<_DimEntry> _timbreEntries() => <_DimEntry>[
        for (final Timbre t in Timbre.values)
          _DimEntry(_timbreLabel(t), dimensions.timbreBucket(t)),
      ];

  List<_DimEntry> _rootEntries() => <_DimEntry>[
        for (final RootMode r in RootMode.values)
          _DimEntry(_rootLabel(r), dimensions.rootModeBucket(r)),
      ];

  String _directionLabel(PlaybackDirection d) => switch (d) {
        PlaybackDirection.ascending => AppStrings.freeTraining.directionAscending,
        PlaybackDirection.descending => AppStrings.freeTraining.directionDescending,
        PlaybackDirection.harmonic => AppStrings.freeTraining.directionHarmonic,
      };

  String _timbreLabel(Timbre t) => switch (t) {
        Timbre.keyboard => AppStrings.freeTraining.timbreKeyboard,
        Timbre.plucked => AppStrings.freeTraining.timbrePlucked,
      };

  String _rootLabel(RootMode r) => switch (r) {
        RootMode.fixed => AppStrings.freeTraining.rootFixed,
        RootMode.limitedRandom => AppStrings.freeTraining.rootLimitedRandom,
        RootMode.fullRandom => AppStrings.freeTraining.rootFullRandom,
      };
}

/// 维度条目（标签 + 计数桶）。
class _DimEntry {
  const _DimEntry(this.label, this.bucket);

  final String label;
  final AccuracyBucket bucket;
}

/// 单个维度分组（标题 + 各取值进度条）。
class _DimensionGroup extends StatelessWidget {
  const _DimensionGroup({required this.title, required this.entries});

  final String title;
  final List<_DimEntry> entries;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<_DimEntry> nonEmpty =
        entries.where((e) => !e.bucket.isEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: tokens.type.labelLarge),
        SizedBox(height: tokens.space.xs),
        if (nonEmpty.isEmpty)
          Text(
            AppStrings.common.empty,
            style: tokens.type.bodySmall
                ?.copyWith(color: tokens.scheme.onSurfaceVariant),
          )
        else
          for (final _DimEntry e in nonEmpty) _DimRow(entry: e),
      ],
    );
  }
}

/// 单条维度进度（标签 + 进度条 + 百分比）。
class _DimRow extends StatelessWidget {
  const _DimRow({required this.entry});

  final _DimEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final double acc = entry.bucket.accuracy();
    final Color barColor =
        acc >= 0.6 ? tokens.color.success.base : tokens.color.warning.base;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.space.xxs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(entry.label, style: tokens.type.bodySmall),
          ),
          SizedBox(width: tokens.space.sm),
          Expanded(
            child: LinearProgressIndicator(
              value: acc,
              color: barColor,
              backgroundColor: tokens.scheme.surfaceContainerHighest,
              minHeight: 8,
            ),
          ),
          SizedBox(width: tokens.space.sm),
          SizedBox(
            width: 44,
            child: Text(
              '${MathUtils.toPercent(acc)}%',
              style: tokens.type.bodySmall
                  ?.copyWith(color: tokens.scheme.onSurfaceVariant),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
