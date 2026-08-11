import 'dart:typed_data';

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

/// 容许不同 Flutter/Skia 版本对文字边缘的微小抗锯齿差异。
///
/// 0.6% 低于任一图表主体或数据图形改变所占的像素比例，
/// 但能覆盖 Flutter 3.44 字形栅格化产生的 0.11%~0.52% 差异。
class _ReportGoldenComparator extends LocalFileComparator {
  _ReportGoldenComparator(super.testFile);

  static const double tolerance = 0.006;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

/// 在统一的 800×600 / devicePixelRatio 1.0 / textScaler 1.3 画布上渲染任意
/// [CustomPainter]，颜色取自真实设计令牌（[AppTokens]）。
///
/// 不使用任何随机或时间，保证 golden 可复现（验收 ⑦：textScaler=1.3 不重叠）。
Future<void> pumpPainter(
  WidgetTester tester,
  CustomPainter Function(AppTokens tokens) builder,
) async {
  if (goldenFileComparator is! _ReportGoldenComparator) {
    final current = goldenFileComparator;
    final testFile = current is LocalFileComparator
        ? current.basedir.resolve('__report_golden_test.dart')
        : Uri.parse('test/features/report/painters/__report_golden_test.dart');
    goldenFileComparator = _ReportGoldenComparator(testFile);
  }
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
