import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/features/report/presentation/painters/heatmap_painter.dart';
import 'painter_golden_helpers.dart';

void main() {
  testWidgets('HeatmapPainter 终态 golden 对照', (tester) async {
    await pumpPainter(tester, (AppTokens tokens) {
      return HeatmapPainter(
        values: List<double>.generate(35, (int i) => (i % 7) / 7),
        rows: 7,
        grow: 1,
        baseColor: tokens.color.success.base,
        emptyColor: tokens.scheme.surfaceContainerHighest,
        gap: tokens.space.xxs,
      );
    });
    await expectLater(
      find.byKey(goldenCanvasKey),
      matchesGoldenFile('goldens/heatmap.png'),
    );
  });
}
