import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/features/report/presentation/painters/line_chart_painter.dart';
import 'painter_golden_helpers.dart';

void main() {
  testWidgets('LineChartPainter 描边终态 golden 对照', (tester) async {
    await pumpPainter(tester, (AppTokens tokens) {
      return LineChartPainter(
        values: const <double>[0.6, 0.7, 0.55, 0.8, 0.75, 0.9, 0.85],
        labels: const <String>[
          '6/9',
          '6/10',
          '6/11',
          '6/12',
          '6/13',
          '6/14',
          '6/15',
        ],
        grow: 1,
        lineColor: tokens.color.success.base,
        areaColor: tokens.color.success.base.withValues(alpha: 0.15),
        gridColor: tokens.scheme.outlineVariant,
        axisColor: tokens.scheme.outline,
        labelColor: tokens.scheme.onSurfaceVariant,
      );
    });
    await expectLater(
      find.byKey(goldenCanvasKey),
      matchesGoldenFile('goldens/line_chart.png'),
    );
  });
}
