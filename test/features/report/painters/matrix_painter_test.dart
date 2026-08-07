import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/features/report/presentation/painters/matrix_painter.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'painter_golden_helpers.dart';

int _cell(int r, int c, int n) {
  if (r == c) {
    return 5 + (r % 5);
  }
  if (c == (r + 1) % n) {
    return 2 + (r % 3);
  }
  return 0;
}

void main() {
  final List<IntervalId> ids = IntervalCatalog.trainableIds.toList();
  final List<List<int>> counts = <List<int>>[
    for (int r = 0; r < ids.length; r++)
      <int>[
        for (int c = 0; c < ids.length; c++) _cell(r, c, ids.length),
      ],
  ];
  var maxCount = 0;
  for (final List<int> row in counts) {
    for (final int v in row) {
      if (v > maxCount) {
        maxCount = v;
      }
    }
  }
  final List<String> labels = <String>[
    for (final IntervalId id in ids) IntervalCatalog.shorthandOf(id),
  ];

  testWidgets('MatrixPainter 波次终态 golden 对照', (tester) async {
    await pumpPainter(tester, (AppTokens tokens) {
      return MatrixPainter(
        counts: counts,
        reveal: 1,
        maxCount: maxCount,
        diagonalColor: tokens.color.success.base,
        offColor: tokens.color.warning.base,
        textColor: tokens.scheme.onSurface,
        gridColor: tokens.scheme.outlineVariant,
        emptyColor: tokens.scheme.surfaceContainerHighest,
        rowLabels: labels,
        columnLabels: labels,
      );
    });
    await expectLater(
      find.byKey(goldenCanvasKey),
      matchesGoldenFile('goldens/matrix.png'),
    );
  });
}
