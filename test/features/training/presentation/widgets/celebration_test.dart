// T14 验收：正确庆祝 / 连击徽章 / 章节推进浮层。
//
// 覆盖 (E)：
// - celebration_level 粒子数阈值（particleCountFor：subtle/rich/off 三档）。
// - ComboBadge：combo<=0 不渲染；full 档渲染旋转环；reduced 档停环保留终态文字；
//   连击数增加时文本增量更新。
// - ChapterAdvanceOverlay：显示章节名；动画结束后调用 onDismissed；
//   reduced / off 档不崩溃且仍能到达终态（onDismissed 触发）。
//
// 全部使用 FakeAudioService 无关组件，仅依赖 AppTheme + MotionScope 提供动效档位。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/presentation/widgets/celebration_layer.dart';
import 'package:interval_ear/features/training/presentation/widgets/combo_badge.dart';
import 'package:interval_ear/features/training/presentation/widgets/chapter_advance_overlay.dart';
import 'package:interval_ear/features/training/presentation/widgets/particle_system.dart';

/// 包裹待测组件，提供完整 ThemeExtension 主题，并按需挂载 MotionScope 动效档位。
Widget _bootstrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  MotionLevel? level,
}) {
  final ThemeData theme =
      brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;
  final scaffold = Scaffold(
    body: Center(
      // ChapterAdvanceOverlay 根节点为 Positioned.fill，必须有 Stack 祖先；
      // 用 StackFit.expand 让其占满约束区域（等价于真实 app 的全屏浮层）。
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[child],
      ),
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

void main() {
  group('T14 celebration_level 粒子数阈值（particleCountFor 纯函数）', () {
    test('off 档恒为 0（任何连击都不庆祝）', () {
      for (final combo in const <int>[-1, 0, 1, 3, 5, 9, 10, 20]) {
        expect(particleCountFor(combo, CelebrationLevel.off), 0,
            reason: 'combo=$combo');
      }
    });

    test('subtle 档阈值：<3→0，3-4→8，5-9→14，≥10→20', () {
      // 低于阈值：完全不庆祝。
      for (final combo in const <int>[-1, 0, 1, 2]) {
        expect(particleCountFor(combo, CelebrationLevel.subtle), 0,
            reason: 'combo=$combo');
      }
      for (final combo in const <int>[3, 4]) {
        expect(particleCountFor(combo, CelebrationLevel.subtle), 8,
            reason: 'combo=$combo');
      }
      for (final combo in const <int>[5, 6, 9]) {
        expect(particleCountFor(combo, CelebrationLevel.subtle), 14,
            reason: 'combo=$combo');
      }
      for (final combo in const <int>[10, 15, 20]) {
        expect(particleCountFor(combo, CelebrationLevel.subtle), 20,
            reason: 'combo=$combo');
      }
    });

    test('rich 档：阈值整体下调 2 档且粒子数 ×1.6', () {
      // 阈值下调：原本 <3 才是 0，rich 下 <1 才是 0。
      for (final combo in const <int>[-1, 0]) {
        expect(particleCountFor(combo, CelebrationLevel.rich), 0,
            reason: 'combo=$combo');
      }
      // 1-2 → 8 × 1.6 = 12.8 → 13。
      for (final combo in const <int>[1, 2]) {
        expect(particleCountFor(combo, CelebrationLevel.rich), 13,
            reason: 'combo=$combo');
      }
      // 3-7 → 14 × 1.6 = 22.4 → 22。
      for (final combo in const <int>[3, 5, 7]) {
        expect(particleCountFor(combo, CelebrationLevel.rich), 22,
            reason: 'combo=$combo');
      }
      // ≥8 → 20 × 1.6 = 32。
      for (final combo in const <int>[8, 10, 20]) {
        expect(particleCountFor(combo, CelebrationLevel.rich), 32,
            reason: 'combo=$combo');
      }
    });

    test('rich 档粒子数在相同连击下严格多于 subtle 档', () {
      for (final combo in const <int>[3, 5, 10, 15]) {
        expect(
          particleCountFor(combo, CelebrationLevel.rich),
          greaterThan(particleCountFor(combo, CelebrationLevel.subtle)),
          reason: 'combo=$combo',
        );
      }
    });
  });

  group('T14 ComboBadge', () {
    testWidgets('combo<=0 不渲染任何内容（SizedBox.shrink）', (tester) async {
      await tester.pumpWidget(_bootstrap(const ComboBadge(combo: 0)));
      // 连击文字不应出现。
      expect(find.text(AppStrings.training.comboCount(0)), findsNothing);
      // 组件仍在树中，但主体被 SizedBox 替代。
      expect(find.byType(ComboBadge), findsOneWidget);
    });

    testWidgets('full 档：combo>0 渲染连击文字 + 环境旋转环', (tester) async {
      await tester.pumpWidget(
        _bootstrap(const ComboBadge(combo: 3), level: MotionLevel.full),
      );
      expect(find.text(AppStrings.training.comboCount(3)), findsOneWidget);
      // full 档允许 ambient → 旋转环存在。
      // 作用域限定在 ComboBadge 内，排除 MaterialApp 默认页面转场
      // (ZoomPageTransitionsBuilder) 自带的一个 RotationTransition。
      expect(
        find.descendant(
          of: find.byType(ComboBadge),
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reduced 档：停掉旋转环但保留终态文字', (tester) async {
      await tester.pumpWidget(
        _bootstrap(const ComboBadge(combo: 3), level: MotionLevel.reduced),
      );
      // 终态（连击数字）必须可见——禁止把整个组件 if 掉。
      expect(find.text(AppStrings.training.comboCount(3)), findsOneWidget);
      // reduced 档不允许 ambient → 旋转环不渲染。
      // 同样作用域限定在 ComboBadge 内，排除 MaterialApp 转场自带的 RotationTransition。
      expect(
        find.descendant(
          of: find.byType(ComboBadge),
          matching: find.byType(RotationTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('连击数增加时文本增量更新', (tester) async {
      await tester.pumpWidget(
        _bootstrap(const ComboBadge(combo: 3), level: MotionLevel.full),
      );
      expect(find.text(AppStrings.training.comboCount(3)), findsOneWidget);

      // 重新构建为更高连击。
      await tester.pumpWidget(
        _bootstrap(const ComboBadge(combo: 5), level: MotionLevel.full),
      );
      expect(find.text(AppStrings.training.comboCount(5)), findsOneWidget);
      expect(find.text(AppStrings.training.comboCount(3)), findsNothing);
    });
  });

  group('T14 CelebrationLayer', () {
    testWidgets('off 档不渲染粒子系统', (tester) async {
      await tester.pumpWidget(_bootstrap(const CelebrationLayer(
        combo: 10,
        level: CelebrationLevel.off,
        color: Colors.amber,
      )));
      expect(find.byType(ParticleSystem), findsNothing);
    });

    testWidgets('subtle 档在里程碑连击时渲染粒子系统 + 连击弹层', (tester) async {
      // combo=5 是里程碑（kComboMilestones 含 5），count=14>0。
      await tester.pumpWidget(_bootstrap(const CelebrationLayer(
        combo: 5,
        level: CelebrationLevel.subtle,
        color: Colors.amber,
      )));
      // 粒子系统组件在树中（MotionScope.fallback 为 full，允许粒子）。
      expect(find.byType(ParticleSystem), findsOneWidget);
      // 里程碑弹层文字出现。
      expect(find.text(AppStrings.training.comboCount(5)), findsOneWidget);
    });
  });

  group('T14 ChapterAdvanceOverlay', () {
    testWidgets('full 档：显示章节名，动画结束后调用 onDismissed', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(_bootstrap(
        ChapterAdvanceOverlay(
          chapterName: 'C 大调音阶',
          onDismissed: () => dismissed = true,
        ),
        level: MotionLevel.full,
      ));
      // 章节推进文案可见。
      expect(
        find.text(AppStrings.training.chapterAdvance('C 大调音阶')),
        findsOneWidget,
      );

      // 等动画走完（enter 300 + hold 1600 + exit 240 = 2140ms）。
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('reduced 档：终态文案仍显示且 onDismissed 触发', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(_bootstrap(
        ChapterAdvanceOverlay(
          chapterName: 'G 大调音阶',
          onDismissed: () => dismissed = true,
        ),
        level: MotionLevel.reduced,
      ));
      // 即便精简动效，文案（终态）必须出现。
      expect(
        find.text(AppStrings.training.chapterAdvance('G 大调音阶')),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('off 档：不崩溃、onDismissed 立即触发（到达终态）', (tester) async {
      var dismissed = false;
      // off 档时长折为 0，应瞬时完成并 dismiss，不得抛异常。
      await tester.pumpWidget(_bootstrap(
        ChapterAdvanceOverlay(
          chapterName: 'D 大调音阶',
          onDismissed: () => dismissed = true,
        ),
        level: MotionLevel.off,
      ));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });
  });
}
