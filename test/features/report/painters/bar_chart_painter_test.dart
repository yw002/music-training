import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/features/report/presentation/painters/bar_chart_painter.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'painter_golden_helpers.dart';

void main() {
  final List<IntervalId> ids = IntervalCatalog.trainableIds.toList();

  testWidgets('BarChartPainter 全生长终态 golden 对照', (tester) async {
    await pumpPainter(tester, (AppTokens tokens) {
      final List<double> values = <double>[
        for (final IntervalId id in ids) 0.3 + (id.semitones % 7) / 10,
      ];
      final List<String> labels = <String>[
        for (final IntervalId id in ids) IntervalCatalog.shorthandOf(id),
      ];
      final List<Color> colors = <Color>[
        for (final IntervalId id in ids) tokens.interval.colorOf(id.semitones),
      ];
      return BarChartPainter(
        values: values,
        labels: labels,
        barColors: colors,
        barProgress: List<double>.filled(ids.length, 1),
        trackColor: tokens.scheme.surfaceContainerHighest,
        axisColor: tokens.scheme.outlineVariant,
        labelColor: tokens.scheme.onSurfaceVariant,
        gridColor: tokens.scheme.outlineVariant,
      );
    });
    await expectLater(
      find.byKey(goldenCanvasKey),
      matchesGoldenFile('goldens/bar_chart.png'),
    );
  });
}
