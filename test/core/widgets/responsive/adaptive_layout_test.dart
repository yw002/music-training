// T22 自适应布局与桌面 tooltip（架构 §1.4 / M-33）。
//
// 验证 [AdaptiveLayout] 三档限宽、[AdaptiveGrid] 多列/单列、[AdaptiveTooltip]
// 仅桌面 hover 显示（移动端直接返回子树）。覆盖验收 ①（三档无溢出）的布局层与
// 验收 ⑤（M-33 tooltip 仅桌面）。
//
// 用 `tester.view.physicalSize` 直接控制窗口宽度（与 report_page_test 同一套打法），
// 避免「MediaQuery 嵌套在 MaterialApp 内」的歧义。

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/platform/platform_capabilities.dart';
import 'package:interval_ear/core/widgets/responsive/adaptive_layout.dart';
import 'package:interval_ear/core/widgets/responsive/breakpoint_scope.dart';
import 'package:interval_ear/core/widgets/responsive/responsive_builder.dart';

void main() {
  // 静态平台能力注入在每个用例后清掉，避免污染。
  tearDown(() => PlatformCapabilities.debugOverride(null));

  /// 在给定逻辑宽度下挂载 [child]，返回用 [ResponsiveBuilder] 提供断点作用域。
  Future<void> pumpAt(WidgetTester tester, Widget child, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    // 用例结束还原物理尺寸，避免影响后续用例。
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ResponsiveBuilder(
          builder: (BuildContext context, Breakpoint bp) => child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AdaptiveLayout 限宽', () {
    testWidgets('expanded 断点把内容限宽到 1080 并居中', (tester) async {
      await pumpAt(
        tester,
        AdaptiveLayout(
          child: Container(width: 5000, height: 40, color: Colors.red),
        ),
        1200,
      );
      // ConstrainedBox(maxWidth:1080) 把 5000 宽压到 1080。
      expect(tester.getSize(find.byType(Container)).width, 1080);
    });

    testWidgets('compact 断点内容全宽（不限制）', (tester) async {
      await pumpAt(
        tester,
        AdaptiveLayout(
          child: Container(width: 5000, height: 40, color: Colors.red),
        ),
        400,
      );
      // 不限宽时 Container 受父级（视口 400）约束，渲染宽度 = 400。
      expect(tester.getSize(find.byType(Container)).width, 400);
    });
  });

  group('AdaptiveGrid 列数', () {
    List<Widget> _cells() => List<Widget>.generate(
          4,
          (int i) => Container(
            key: ValueKey<int>(i),
            width: 100,
            height: 40,
            color: Colors.blue,
          ),
        );

    testWidgets('expanded 多列：同行不同列', (tester) async {
      await pumpAt(tester, AdaptiveGrid(columns: 2, children: _cells()), 1200);

      final Offset c0 = tester.getTopLeft(find.byKey(const ValueKey<int>(0)));
      final Offset c1 = tester.getTopLeft(find.byKey(const ValueKey<int>(1)));
      expect(c0.dy, c1.dy); // 同一行
      expect(c1.dx, greaterThan(c0.dx)); // 不同列
    });

    testWidgets('单列：同列不同行', (tester) async {
      await pumpAt(tester, AdaptiveGrid(columns: 1, children: _cells()), 400);

      final Offset s0 = tester.getTopLeft(find.byKey(const ValueKey<int>(0)));
      final Offset s1 = tester.getTopLeft(find.byKey(const ValueKey<int>(1)));
      expect(s0.dx, s1.dx); // 同列
      expect(s1.dy, greaterThan(s0.dy)); // 不同行
    });

    testWidgets('空 children 不崩溃', (tester) async {
      await pumpAt(
        tester,
        const AdaptiveGrid(children: <Widget>[]),
        1200,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AdaptiveTooltip 仅桌面显示', () {
    testWidgets('桌面 hover 后出现气泡', (tester) async {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.desktop());
      await pumpAt(
        tester,
        Center(
          child: AdaptiveTooltip(
            message: 'tip-msg',
            child: Container(width: 80, height: 40, color: Colors.teal),
          ),
        ),
        1200,
      );

      expect(find.text('tip-msg'), findsNothing); // 未 hover

      final Offset center = tester.getCenter(find.byType(Container));
      final TestGesture gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(center);
      // M-33：500ms 延迟 + 140ms 淡入。
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('tip-msg'), findsOneWidget);
    });

    testWidgets('移动端直接返回 child，hover 也不显示气泡', (tester) async {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.mobile());
      await pumpAt(
        tester,
        const Center(child: AdaptiveTooltip(
          message: 'tip-mobile',
          child: Text('child-widget'),
        )),
        400,
      );

      expect(find.text('child-widget'), findsOneWidget);

      final Offset center = tester.getCenter(find.text('child-widget'));
      final TestGesture gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('tip-mobile'), findsNothing);
    });
  });
}
