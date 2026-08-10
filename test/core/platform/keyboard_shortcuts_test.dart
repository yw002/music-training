// T22 桌面快捷键装配（架构 §1.4 / PRD §6.2）。
//
// 验证 [AppShortcuts] 的按键 → 意图映射与回调触发：数字选答案、空格重播、
// 回车下一题、U 不确定、Esc 返回、Ctrl/⌘ 组合键；文本框聚焦时让路；
// [enabled]=false 时完全透明。另验证 [primaryModifier] 与 [buildShortcutMap]。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/platform/keyboard_shortcuts.dart';
import 'package:interval_ear/core/platform/platform_capabilities.dart';

void main() {
  tearDown(() => PlatformCapabilities.debugOverride(null));

  /// 包裹 [AppShortcuts]，提供 Material 环境（Scaffold 让 Focus 有挂载点）。
  Future<void> pumpApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AppShortcuts 按键触发回调', () {
    testWidgets('数字键 1/0 选中答案下标 0/9', (tester) async {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.desktop());
      final List<int> selected = <int>[];
      await pumpApp(
        tester,
        AppShortcuts(
          onSelectAnswer: selected.add,
          child: const SizedBox.shrink(),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pump();

      expect(selected, <int>[0, 9]);
    });

    testWidgets('空格触发重播、回车触发下一题', (tester) async {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.desktop());
      int replayed = 0;
      int next = 0;
      await pumpApp(
        tester,
        AppShortcuts(
          onReplay: () => replayed++,
          onNext: () => next++,
          child: const SizedBox.shrink(),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(replayed, 1);
      expect(next, 1);
    });

    testWidgets('U 键触发不确定', (tester) async {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.desktop());
      int uncertain = 0;
      await pumpApp(
        tester,
        AppShortcuts(
          onUncertain: () => uncertain++,
          child: const SizedBox.shrink(),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.pump();

      expect(uncertain, 1);
    });

    testWidgets('Esc 触发返回', (tester) async {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.desktop());
      int dismissed = 0;
      await pumpApp(
        tester,
        AppShortcuts(
          onDismiss: () => dismissed++,
          child: const SizedBox.shrink(),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(dismissed, 1);
    });
  });

  group('AppShortcuts 文本框让路', () {
    testWidgets('文本框聚焦时数字键不触发选答案', (tester) async {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.desktop());
      final List<int> selected = <int>[];
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      // autofocus:false 让 AppShortcuts 内部 Focus 不参与抢焦点，文本框才能稳定持有焦点。
      await pumpApp(
        tester,
        AppShortcuts(
          autofocus: false,
          onSelectAnswer: selected.add,
          child: TextField(focusNode: focusNode, autofocus: true),
        ),
      );

      // 显式把焦点交给文本框（EditableText 持有焦点）。
      focusNode.requestFocus();
      await tester.pump();

      // 主焦点落在文本框上，快捷键应让路。
      expect(AppShortcuts.isTextFieldFocused, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();

      expect(selected, isEmpty);
    });
  });

  group('AppShortcuts enabled=false 透明', () {
    testWidgets('enabled=false 直接返回 child，快捷键不生效', (tester) async {
      int called = 0;
      await pumpApp(
        tester,
        AppShortcuts(
          enabled: false,
          onReplay: () => called++,
          child: const Text('child-only'),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(called, 0);
      expect(find.text('child-only'), findsOneWidget);
    });
  });

  group('AppShortcuts 静态辅助', () {
    test('primaryModifier：apple 桌面返回 meta，否则 control', () {
      PlatformCapabilities.debugOverride(
        const PlatformCapabilities.desktop(apple: true),
      );
      expect(AppShortcuts.primaryModifier, LogicalKeyboardKey.meta);

      PlatformCapabilities.debugOverride(const PlatformCapabilities.desktop());
      expect(AppShortcuts.primaryModifier, LogicalKeyboardKey.control);
    });

    test('buildShortcutMap 覆盖数字/空格/回车/U/Esc/修饰键意图', () {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.desktop());
      final Map<ShortcutActivator, Intent> map =
          AppShortcuts.buildShortcutMap();

      // SingleActivator 不重写 ==，只能按 trigger 在条目里反查（避免 const/非 const
      // 实例的 identity 差异）。动态构建的数字/小键盘键必须用这种查法。
      Intent? findByTrigger(LogicalKeyboardKey trigger, {bool control = false}) {
        for (final MapEntry<ShortcutActivator, Intent> entry in map.entries) {
          final ShortcutActivator key = entry.key;
          if (key is SingleActivator &&
              key.trigger == trigger &&
              key.control == control) {
            return entry.value;
          }
        }
        return null;
      }

      expect(findByTrigger(LogicalKeyboardKey.space), isA<ReplayIntent>());
      expect(findByTrigger(LogicalKeyboardKey.enter), isA<NextStepIntent>());
      expect(findByTrigger(LogicalKeyboardKey.keyU), isA<UncertainIntent>());
      expect(findByTrigger(LogicalKeyboardKey.escape), isA<AppDismissIntent>());
      expect(findByTrigger(LogicalKeyboardKey.digit1), isA<SelectAnswerIntent>());
      expect(findByTrigger(LogicalKeyboardKey.numpad0), isA<SelectAnswerIntent>());
      expect(
        findByTrigger(LogicalKeyboardKey.keyR, control: true),
        isA<StartTrainingIntent>(),
      );
      expect(
        findByTrigger(LogicalKeyboardKey.comma, control: true),
        isA<OpenSettingsIntent>(),
      );
      expect(
        findByTrigger(LogicalKeyboardKey.keyE, control: true),
        isA<ExportDataIntent>(),
      );
    });
  });
}
