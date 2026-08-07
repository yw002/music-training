import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/features/report/presentation/painters/ring_painter.dart';
import 'painter_golden_helpers.dart';

void main() {
  testWidgets('RingPainter 生长终态 golden 对照', (tester) async {
    await pumpPainter(tester, (AppTokens tokens) {
      return RingPainter(
        progress: 0.73,
        grow: 1,
        trackColor: tokens.scheme.surfaceContainerHighest,
        arcColor: tokens.color.success.base,
        stroke: tokens.space.md,
      );
    });
    await expectLater(
      find.byKey(goldenCanvasKey),
      matchesGoldenFile('goldens/ring.png'),
    );
  });
}
