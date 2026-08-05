// 组件层（T03）单元测试：AppButton / AppSnackBar / WarningBanner。
//
// 覆盖点：
//  - AppButton：标签渲染、Semantics(button/enabled/label)、禁用态、5 种变体、
//    最小触控目标 48×48、按下缩放仅在 full 档位生效、semanticLabel 覆盖。
//  - AppSnackBar：show 返回 ScaffoldFeatureController、4 种 tone 文案可见、
//    showError 使用「重试」动作标签（M-31）。
//  - WarningBanner：info/warning/error 文案、visible=false 收起、liveRegion
//    无障碍语义、onDismiss / onAction 回调触发。
//
// 注意：组件树未挂载 MotionScope 时走 MotionScopeData.fallback（full），
// 因此默认测试即验证 full 行为；需要 reduced/off 时显式包一层 MotionScope。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/core/widgets/app_button.dart';
import 'package:interval_ear/core/widgets/app_snackbar.dart';
import 'package:interval_ear/core/widgets/warning_banner.dart';

/// 无副作用的占位回调。
void _noop() {}

/// 包裹一个待测组件，提供已挂载全部 ThemeExtension 的主题。
///
/// [level] 非 null 时额外用 [MotionScope] 固定动效档位，用于验证降级行为。
Widget _bootstrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  MotionLevel? level,
}) {
  final ThemeData theme =
      brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;
  final Scaffold scaffold = Scaffold(
    body: Center(
      child: SizedBox(width: 240, height: 80, child: child),
    ),
  );
  if (level == null) {
    return MaterialApp(theme: theme, home: scaffold);
  }
  return MaterialApp(
    theme: theme,
    home: MotionScope(
      data: MotionScopeData(
        level: level,
        stage: MotionDegradeStage.none,
        userPreference: MotionPreference.system,
        systemReduceMotion: false,
      ),
      child: scaffold,
    ),
  );
}

/// 找到 AppButton 自身（properties.button == true）的 Semantics。
Semantics _buttonSemantics(WidgetTester tester) => tester.widget<Semantics>(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.button == true,
      ),
    );

void main() {
  group('AppButton', () {
    testWidgets('renders label and exposes button semantics', (tester) async {
      await tester.pumpWidget(
        _bootstrap(const AppButton(label: '开始训练', onPressed: _noop)),
      );

      expect(find.text('开始训练'), findsOneWidget);

      final Semantics semantics = _buttonSemantics(tester);
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.enabled, isTrue);
      expect(semantics.properties.label, '开始训练');
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _bootstrap(const AppButton(label: 'X', onPressed: null)),
      );

      final Semantics semantics = _buttonSemantics(tester);
      expect(semantics.properties.enabled, isFalse);
    });

    testWidgets('uses semanticLabel override', (tester) async {
      await tester.pumpWidget(
        _bootstrap(
          const AppButton(
            label: '播放',
            onPressed: _noop,
            semanticLabel: '无障碍标签',
          ),
        ),
      );

      expect(_buttonSemantics(tester).properties.label, '无障碍标签');
    });

    for (final AppButtonVariant variant in AppButtonVariant.values) {
      testWidgets('variant $variant builds and shows label', (tester) async {
        await tester.pumpWidget(
          _bootstrap(
            AppButton(label: 'L', variant: variant, onPressed: _noop),
          ),
        );
        expect(find.text('L'), findsWidgets);
      });
    }

    testWidgets('honours min 48x48 touch target', (tester) async {
      await tester.pumpWidget(
        _bootstrap(const AppButton(label: 'T', onPressed: _noop)),
      );

      final Finder container = find.ancestor(
        of: find.text('T'),
        matching: find.byType(AnimatedContainer),
      );
      final AnimatedContainer ac = tester.widget<AnimatedContainer>(container);
      expect(ac.constraints?.minHeight, 48);
      expect(ac.constraints?.minWidth, 48);
    });

    testWidgets('scales down only at full motion level', (tester) async {
      // full 档位：按下时缩放至 0.97。
      await tester.pumpWidget(
        _bootstrap(
          const AppButton(label: 'P', onPressed: _noop),
          level: MotionLevel.full,
        ),
      );

      final Finder scaleFinder = find.ancestor(
        of: find.text('P'),
        matching: find.byType(AnimatedScale),
      );
      expect(tester.widget<AnimatedScale>(scaleFinder).scale, 1.0);

      final Offset center = tester.getCenter(find.text('P'));
      final TestGesture gesture = await tester.startGesture(center);
      await tester.pump();
      expect(tester.widget<AnimatedScale>(scaleFinder).scale, 0.97);
      await gesture.up();

      // reduced 档位：即使按下也不缩放。
      await tester.pumpWidget(
        _bootstrap(
          const AppButton(label: 'P', onPressed: _noop),
          level: MotionLevel.reduced,
        ),
      );
      final Finder scaleFinder2 = find.ancestor(
        of: find.text('P'),
        matching: find.byType(AnimatedScale),
      );
      final Offset center2 = tester.getCenter(find.text('P'));
      final TestGesture gesture2 = await tester.startGesture(center2);
      await tester.pump();
      expect(tester.widget<AnimatedScale>(scaleFinder2).scale, 1.0);
      await gesture2.up();
    });
  });

  group('AppSnackBar', () {
    Future<void> pumpShowHarness(
      WidgetTester tester,
      void Function(BuildContext context) trigger,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => ElevatedButton(
                onPressed: () => trigger(context),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('show returns a ScaffoldFeatureController', (tester) async {
      late ScaffoldFeatureController<SnackBar, SnackBarClosedReason> ctrl;
      await pumpShowHarness(tester, (BuildContext context) {
        ctrl = AppSnackBar.show(
          context,
          message: '提示文案',
          tone: AppSnackBarTone.neutral,
        );
      });

      await tester.tap(find.text('show'));
      expect(ctrl.closed, isA<Future<SnackBarClosedReason>>());

      await tester.pumpAndSettle();
      expect(find.text('提示文案'), findsOneWidget);
    });

    for (final AppSnackBarTone tone in AppSnackBarTone.values) {
      testWidgets('tone $tone shows message', (tester) async {
        await pumpShowHarness(tester, (BuildContext context) {
          AppSnackBar.show(context, message: 'MSG', tone: tone);
        });

        await tester.tap(find.text('show'));
        await tester.pumpAndSettle();
        expect(find.text('MSG'), findsOneWidget);
      });
    }

    testWidgets('showError uses retry action label', (tester) async {
      await pumpShowHarness(tester, (BuildContext context) {
        AppSnackBar.showError(context, message: '出错了');
      });

      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();
      expect(find.text('出错了'), findsOneWidget);
      expect(
        find.widgetWithText(SnackBarAction, AppStrings.common.retry),
        findsOneWidget,
      );
    });
  });

  group('WarningBanner', () {
    for (final WarningBannerTone tone in WarningBannerTone.values) {
      testWidgets('tone $tone shows message', (tester) async {
        await tester.pumpWidget(
          _bootstrap(WarningBanner(message: 'M', tone: tone)),
        );
        expect(find.text('M'), findsOneWidget);
      });
    }

    testWidgets('hidden when visible is false', (tester) async {
      await tester.pumpWidget(
        _bootstrap(const WarningBanner(message: 'H', visible: false)),
      );
      expect(find.text('H'), findsNothing);
    });

    testWidgets('exposes liveRegion semantics', (tester) async {
      await tester.pumpWidget(
        _bootstrap(const WarningBanner(message: 'LR')),
      );

      final Semantics semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (Widget w) => w is Semantics && w.properties.liveRegion == true,
        ),
      );
      expect(semantics.properties.label, 'LR');
    });

    testWidgets('triggers onDismiss', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        _bootstrap(
          WarningBanner(
            message: 'D',
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('triggers onAction', (tester) async {
      bool acted = false;
      await tester.pumpWidget(
        _bootstrap(
          WarningBanner(
            message: 'A',
            actionLabel: '重试',
            onAction: () => acted = true,
          ),
        ),
      );

      expect(find.widgetWithText(TextButton, '重试'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '重试'));
      await tester.pumpAndSettle();
      expect(acted, isTrue);
    });
  });
}
