import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_level_resolver.dart';

/// T03 验收项：`MotionLevelResolver` 的**完整真值表**。
///
/// 三路输入：`systemReduceMotion`(2) × `userSetting`(4) × `governorDegraded`(2)
/// = 16 种组合，全部逐条断言，一条不落。
void main() {
  MotionLevel resolve({
    required bool system,
    required MotionPreference user,
    required bool degraded,
  }) =>
      MotionLevelResolver.resolve(
        systemReduceMotion: system,
        userSetting: user,
        governorDegraded: degraded,
      );

  group('MotionLevelResolver 完整真值表（16 组）', () {
    /// (systemReduceMotion, userSetting, governorDegraded) -> 期望级别。
    const List<(bool, MotionPreference, bool, MotionLevel)> table =
        <(bool, MotionPreference, bool, MotionLevel)>[
      // userSetting == off：无条件 off，优先级最高。
      (false, MotionPreference.off, false, MotionLevel.off),
      (false, MotionPreference.off, true, MotionLevel.off),
      (true, MotionPreference.off, false, MotionLevel.off),
      (true, MotionPreference.off, true, MotionLevel.off),
      // 系统减弱动效 → reduced（架构 §8.4：系统开关优先于用户的 full）。
      (true, MotionPreference.system, false, MotionLevel.reduced),
      (true, MotionPreference.system, true, MotionLevel.reduced),
      (true, MotionPreference.full, false, MotionLevel.reduced),
      (true, MotionPreference.full, true, MotionLevel.reduced),
      (true, MotionPreference.reduced, false, MotionLevel.reduced),
      (true, MotionPreference.reduced, true, MotionLevel.reduced),
      // 看门狗降级 → reduced（不改写用户设置，仅临时压制）。
      (false, MotionPreference.system, true, MotionLevel.reduced),
      (false, MotionPreference.full, true, MotionLevel.reduced),
      (false, MotionPreference.reduced, true, MotionLevel.reduced),
      // 用户显式 reduced。
      (false, MotionPreference.reduced, false, MotionLevel.reduced),
      // 三路皆放行 → full。
      (false, MotionPreference.system, false, MotionLevel.full),
      (false, MotionPreference.full, false, MotionLevel.full),
    ];

    test('表内 16 组组合逐条匹配', () {
      for (final (bool system, MotionPreference user, bool degraded,
          MotionLevel expected) in table) {
        expect(
          resolve(system: system, user: user, degraded: degraded),
          expected,
          reason: 'system=$system user=$user degraded=$degraded',
        );
      }
    });

    test('真值表覆盖了全部 2 × 4 × 2 = 16 种输入组合', () {
      final Set<String> covered = table
          .map(((bool, MotionPreference, bool, MotionLevel) row) =>
              '${row.$1}|${row.$2.name}|${row.$3}')
          .toSet();
      expect(covered.length, 16);

      for (final bool system in <bool>[false, true]) {
        for (final MotionPreference user in MotionPreference.values) {
          for (final bool degraded in <bool>[false, true]) {
            expect(
              covered.contains('$system|${user.name}|$degraded'),
              isTrue,
              reason: '缺少组合 system=$system user=$user degraded=$degraded',
            );
          }
        }
      }
      expect(MotionPreference.values.length, 4);
      expect(MotionLevel.values.length, 3);
    });
  });

  group('MotionLevelResolver 规则性质', () {
    test('off 是吸收态：任何其他输入都无法把它抬回 full/reduced', () {
      for (final bool system in <bool>[false, true]) {
        for (final bool degraded in <bool>[false, true]) {
          expect(
            resolve(system: system, user: MotionPreference.off, degraded: degraded),
            MotionLevel.off,
          );
        }
      }
    });

    test('看门狗降级永远不会产生 off（只降到 reduced）', () {
      for (final MotionPreference user in <MotionPreference>[
        MotionPreference.system,
        MotionPreference.full,
        MotionPreference.reduced,
      ]) {
        expect(
          resolve(system: false, user: user, degraded: true),
          MotionLevel.reduced,
        );
      }
    });

    test('纯函数：同输入多次调用结果恒定', () {
      for (int i = 0; i < 5; i++) {
        expect(
          resolve(system: false, user: MotionPreference.system, degraded: false),
          MotionLevel.full,
        );
      }
    });

    test('只有 (system=false, degraded=false, user in {system, full}) 才是 full', () {
      int fullCount = 0;
      for (final bool system in <bool>[false, true]) {
        for (final MotionPreference user in MotionPreference.values) {
          for (final bool degraded in <bool>[false, true]) {
            if (resolve(system: system, user: user, degraded: degraded) ==
                MotionLevel.full) {
              fullCount++;
              expect(system, isFalse);
              expect(degraded, isFalse);
              expect(
                user == MotionPreference.system || user == MotionPreference.full,
                isTrue,
              );
            }
          }
        }
      }
      expect(fullCount, 2);
    });
  });

  group('MotionLevel 能力位', () {
    test('full 允许全部效果', () {
      expect(MotionLevel.full.allowsAmbient, isTrue);
      expect(MotionLevel.full.allowsParticles, isTrue);
    });

    test('reduced / off 禁用粒子与环境动效', () {
      for (final MotionLevel level in <MotionLevel>[
        MotionLevel.reduced,
        MotionLevel.off,
      ]) {
        expect(level.allowsAmbient, isFalse, reason: '$level');
        expect(level.allowsParticles, isFalse, reason: '$level');
      }
    });
  });
}
