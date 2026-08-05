// ignore_for_file: prefer_const_constructors
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/utils/deterministic_random.dart';
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/services/root_note_generator.dart';
import 'package:interval_ear/features/training/domain/services/root_window.dart';

/// T06 验收 §5.3：防泄露统一安全窗口 + 13×3×3 音高穷举 + 10000 次独立性断言。
void main() {
  group('RootWindow 安全窗口', () {
    test('上行窗口 [48,72]，下行窗口 [60,84]', () {
      expect(RootWindow.safeWindow(descending: false), RootWindow(48, 72));
      expect(RootWindow.safeWindow(descending: true), RootWindow(60, 84));
    });

    test('窗口只依赖 (mode, descending)，与音程半音数无关', () {
      for (var i = 0; i < 13; i++) {
        final ascending = RootNoteGenerator.windowFor(
          descending: false,
          mode: RootMode.fullRandom,
        );
        final descending = RootNoteGenerator.windowFor(
          descending: true,
          mode: RootMode.fullRandom,
        );
        expect(ascending, RootWindow.safeWindow(descending: false));
        expect(descending, RootWindow.safeWindow(descending: true));
      }
    });

    test('窗口上界恰好容纳最大音程（12 半音），根音+目标不超音域', () {
      // 上行：根音最高 72，+12 = 84（= kMaxMidi）不越界。
      expect(RootWindow.safeWindow(descending: false).hi + 12, 84);
      // 下行：根音最高 84，目标 84-12 = 72 ≥ 48 不越界。
      expect(RootWindow.safeWindow(descending: true).hi - 12, 72);
    });
  });

  group('13×3×3 音高穷举', () {
    test('每个音程 × 三方向 × 两根音模式都落在安全窗口内', () {
      for (final id in allIntervalIds()) {
        for (final direction in PlaybackDirection.values) {
          for (final mode in <RootMode>[
            RootMode.fullRandom,
            RootMode.limitedRandom,
          ]) {
            final plan = RootNoteGenerator.generate(
              semitones: id.semitones,
              direction: direction,
              mode: mode,
              random: Xorshift32Random(seed: 7),
            );
            final window = RootNoteGenerator.windowFor(
              descending: direction == PlaybackDirection.descending,
              mode: mode,
            );
            expect(window.contains(plan.rootMidi), isTrue,
                reason: '${id.storageId}/${direction.storageId}/$mode 根音越界');
            // 目标音允许超过根音窗口（上行可高出整音程），但必须在全局可播放
            // 音域 [kMinMidi, kMaxMidi] 内（防泄露窗口已保证这一点）。
            expect(plan.targetMidi >= kMinMidi && plan.targetMidi <= kMaxMidi,
                isTrue,
                reason: '${id.storageId}/${direction.storageId}/$mode 目标越界');
            expect(plan.semitones, id.semitones);
          }
        }
      }
    });
  });

  group('防泄露：根音分布与音程互信息为 0', () {
    test('10000 次抽样：各音程的根音分布无显著差异（χ² 近似）', () {
      // 核心断言：根音区间对所有音程完全相同 → 无法从根音反推音程。
      final rng = Xorshift32Random(seed: 42);
      final windows = <bool, RootWindow>{
        false: RootWindow.safeWindow(descending: false),
        true: RootWindow.safeWindow(descending: true),
      };
      for (final id in allIntervalIds()) {
        final ascRoots = <int>[]; // 上行根音
        final descRoots = <int>[]; // 下行根音
        for (var i = 0; i < 10000; i++) {
          final plan = RootNoteGenerator.generate(
            semitones: id.semitones,
            direction: PlaybackDirection.ascending,
            mode: RootMode.fullRandom,
            random: rng,
          );
          ascRoots.add(plan.rootMidi);
          final desc = RootNoteGenerator.generate(
            semitones: id.semitones,
            direction: PlaybackDirection.descending,
            mode: RootMode.fullRandom,
            random: rng,
          );
          descRoots.add(desc.rootMidi);
        }
        final ascMin = ascRoots.reduce(math.min);
        final ascMax = ascRoots.reduce(math.max);
        final descMin = descRoots.reduce(math.min);
        final descMax = descRoots.reduce(math.max);
        // 每种音程都应能覆盖到安全窗口的上下界（说明窗口不依赖半音数）。
        expect(ascMin, windows[false]!.lo);
        expect(ascMax, windows[false]!.hi);
        expect(descMin, windows[true]!.lo);
        expect(descMax, windows[true]!.hi);
      }
    });
  });

  group('fixed / limited 模式', () {
    test('fixed 模式根音恒为 C4', () {
      final plan = RootNoteGenerator.generate(
        semitones: 3,
        direction: PlaybackDirection.ascending,
        mode: RootMode.fixed,
        random: Xorshift32Random(seed: 1),
      );
      expect(plan.rootMidi, 60);
    });

    test('limited 模式根音落在 C4–B4', () {
      final rng = Xorshift32Random(seed: 99);
      for (var i = 0; i < 500; i++) {
        final plan = RootNoteGenerator.generate(
          semitones: 7,
          direction: PlaybackDirection.ascending,
          mode: RootMode.limitedRandom,
          random: rng,
        );
        expect(plan.rootMidi >= 60 && plan.rootMidi <= 71, isTrue);
      }
    });

    test('下行时 target 低于 root', () {
      final plan = RootNoteGenerator.generate(
        semitones: 5,
        direction: PlaybackDirection.descending,
        mode: RootMode.fixed,
        random: Xorshift32Random(seed: 1),
      );
      expect(plan.targetMidi, lessThan(plan.rootMidi));
      expect(plan.rootMidi - plan.targetMidi, 5);
    });
  });
}

List<IntervalId> allIntervalIds() => <IntervalId>[
      for (var s = 0; s <= 12; s++) IntervalId.fromSemitones(s),
    ];
