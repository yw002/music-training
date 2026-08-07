import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/session_summary/presentation/widgets/accuracy_ring.dart';

Future<void> pumpRing(
  WidgetTester tester,
  double accuracy,
  MotionLevel level,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MotionScope(
        data: MotionScopeData(
          level: level,
          stage: MotionDegradeStage.none,
          userPreference: MotionPreference.system,
          systemReduceMotion: false,
        ),
        child: Scaffold(
          body: Center(child: AccuracyRing(accuracy: accuracy)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('正确率环以 CustomPaint 渲染，0/1 边界不抛异常', (tester) async {
    await pumpRing(tester, 0.0, MotionLevel.reduced);
    expect(find.byType(CustomPaint), findsWidgets);

    await pumpRing(tester, 1.0, MotionLevel.reduced);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('full 档下 M-26 生长动画收敛后仍存在 CustomPaint', (tester) async {
    await pumpRing(tester, 0.8, MotionLevel.full);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
