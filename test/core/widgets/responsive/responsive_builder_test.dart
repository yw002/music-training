// T22 响应式构建器与断点映射（PRD §6.1 / 架构 §1.4）。
//
// 验证 [Breakpoint.fromWidth] 三档边界，以及 [ResponsiveBuilder] 在不同宽度下
// 向 builder 推送正确的档位。覆盖验收 ①（三档无溢出）的「档位判定」层面。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/widgets/responsive/breakpoint_scope.dart';
import 'package:interval_ear/core/widgets/responsive/responsive_builder.dart';

void main() {
  Widget _wrap(Widget child, double width) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: child,
        ),
      );

  group('Breakpoint.fromWidth 边界', () {
    test('边界：<600 compact, 600–1024 medium, >1024 expanded', () {
      expect(Breakpoint.fromWidth(599), Breakpoint.compact);
      expect(Breakpoint.fromWidth(600), Breakpoint.medium);
      expect(Breakpoint.fromWidth(1024), Breakpoint.medium);
      expect(Breakpoint.fromWidth(1025), Breakpoint.expanded);
    });
  });

  group('ResponsiveBuilder 推送档位', () {
    testWidgets('compact：宽度 400 → compact', (tester) async {
      final List<Breakpoint> captured = <Breakpoint>[];
      await tester.pumpWidget(_wrap(
        ResponsiveBuilder(
          builder: (BuildContext context, Breakpoint bp) {
            captured.add(bp);
            return Text(bp.name, key: const Key('bp'));
          },
        ),
        400,
      ));
      expect(captured.last, Breakpoint.compact);
      expect(find.text('compact'), findsOneWidget);
    });

    testWidgets('medium：宽度 800 → medium', (tester) async {
      final List<Breakpoint> captured = <Breakpoint>[];
      await tester.pumpWidget(_wrap(
        ResponsiveBuilder(
          builder: (BuildContext context, Breakpoint bp) {
            captured.add(bp);
            return Text(bp.name, key: const Key('bp'));
          },
        ),
        800,
      ));
      expect(captured.last, Breakpoint.medium);
      expect(find.text('medium'), findsOneWidget);
    });

    testWidgets('expanded：宽度 1200 → expanded', (tester) async {
      final List<Breakpoint> captured = <Breakpoint>[];
      await tester.pumpWidget(_wrap(
        ResponsiveBuilder(
          builder: (BuildContext context, Breakpoint bp) {
            captured.add(bp);
            return Text(bp.name, key: const Key('bp'));
          },
        ),
        1200,
      ));
      expect(captured.last, Breakpoint.expanded);
      expect(find.text('expanded'), findsOneWidget);
    });

    testWidgets('builder 内可通过 context.breakpoint 读到本层档位', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponsiveBuilder(
          builder: (BuildContext context, Breakpoint bp) =>
              Text(context.breakpoint.name, key: const Key('bp')),
        ),
        1200,
      ));
      expect(find.text('expanded'), findsOneWidget);
    });
  });
}
