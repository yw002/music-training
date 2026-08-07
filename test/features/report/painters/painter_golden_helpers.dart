import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 统一 golden 画布尺寸（验收 ⑦：800×600）。
const Size goldenCanvasSize = Size(800, 600);

/// 供 golden 断言定位的画布 key。
const Key goldenCanvasKey = Key('report-golden-canvas');

/// 在统一的 800×600 / devicePixelRatio 1.0 / textScaler 1.3 画布上渲染任意
/// [CustomPainter]，颜色取自真实设计令牌（[AppTokens]）。
///
/// 不使用任何随机或时间，保证 golden 可复现（验收 ⑦：textScaler=1.3 不重叠）。
Future<void> pumpPainter(
  WidgetTester tester,
  CustomPainter Function(AppTokens tokens) builder,
) async {
  tester.view.physicalSize = goldenCanvasSize;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MotionScope(
        data: MotionScopeData(
          level: MotionLevel.full,
          stage: MotionDegradeStage.none,
          userPreference: MotionPreference.system,
          systemReduceMotion: false,
        ),
        child: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              final AppTokens tokens = context.tokens;
              return Center(
                child: SizedBox(
                  key: goldenCanvasKey,
                  width: goldenCanvasSize.width,
                  height: goldenCanvasSize.height,
                  child: CustomPaint(painter: builder(tokens)),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
