import 'dart:math' as math;

import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/services/root_window.dart';

/// 根音生成（架构 §5.3）。**这是全项目防泄露约束最集中的一处。**
///
/// 输出的 [RootNotePlan] 同时给出根音与目标音，保证两者：
/// 1. 都落在 `[kMinMidi, kMaxMidi]`（音高保护，验收 3 会做 13×3×3 穷举）；
/// 2. 根音分布与音程**完全独立**（防泄露，验收 2 会做 10000 次统计断言）。
///
/// 随机源一律由外部注入（架构 §8.7），本类内部不 new `Random()`。
abstract final class RootNoteGenerator {
  const RootNoteGenerator._();

  /// 为一道题生成根音与目标音。
  ///
  /// [semitones] 是音程半音数 `[0, kMaxSemitones]`；[direction] 是本题已确定的
  /// 播放方向；[mode] 是用户配置的根音策略；[random] 是注入的随机源。
  ///
  /// 越界的 [semitones] 会被夹紧到合法区间——它来自 [IntervalId.semitones]，
  /// 正常不可能越界，夹紧只是防御性兜底。
  static RootNotePlan generate({
    required int semitones,
    required PlaybackDirection direction,
    required RootMode mode,
    required math.Random random,
  }) {
    final steps = semitones < 0
        ? 0
        : (semitones > kMaxSemitones ? kMaxSemitones : semitones);
    final descending = direction == PlaybackDirection.descending;
    final window = windowFor(mode: mode, descending: descending);

    // 关键：窗口只依赖 (mode, descending)，**不依赖 steps**。
    // 因此 root 的分布对所有音程完全一致，听根音推不出音程。
    final root = window.isSingleton
        ? window.lo
        : window.lo + random.nextInt(window.size);

    final target = descending ? root - steps : root + steps;
    return RootNotePlan(
      rootMidi: root,
      targetMidi: target,
      window: window,
      descending: descending,
    );
  }

  /// 给定策略与方向，返回根音窗口。
  ///
  /// 三种策略都最终与「安全窗口」求交，保证任何配置组合下音高都不越界。
  static RootWindow windowFor({
    required RootMode mode,
    required bool descending,
  }) =>
      switch (mode) {
        RootMode.fixed => RootWindow.fixed(),
        RootMode.limitedRandom => RootWindow.limited(descending: descending),
        RootMode.fullRandom => RootWindow.safeWindow(descending: descending),
      };

  /// 固定根音模式下，C4 加上最大音程会不会越界的自检。
  ///
  /// C4 = 60，上行 60 + 12 = 72 ≤ 84，下行 60 - 12 = 48 ≥ 48，两侧都安全。
  /// 单独提出来是为了让「改 [kFixedRootMidi] 时必须重新验算」这件事有据可依，
  /// 测试会直接断言它为 `true`。
  static bool isFixedRootSafe() =>
      kFixedRootMidi + kMaxSemitones <= kMaxMidi &&
      kFixedRootMidi - kMaxSemitones >= kMinMidi;
}

/// 一道题的根音方案（纯数据）。
class RootNotePlan {
  /// 创建方案。
  const RootNotePlan({
    required this.rootMidi,
    required this.targetMidi,
    required this.window,
    required this.descending,
  });

  /// 根音 MIDI 号（先发声的音；和声模式下即较低音）。
  final int rootMidi;

  /// 目标音 MIDI 号。
  final int targetMidi;

  /// 本次取值所用的根音窗口（便于测试断言与问题定位）。
  final RootWindow window;

  /// 是否为下行。
  final bool descending;

  /// 较低音。
  int get lowerMidi => rootMidi <= targetMidi ? rootMidi : targetMidi;

  /// 较高音。
  int get higherMidi => rootMidi >= targetMidi ? rootMidi : targetMidi;

  /// 实际半音跨度。
  int get semitones => (targetMidi - rootMidi).abs();

  /// 两个音是否都在训练音域内。生成器保证恒为 `true`，测试用它做穷举断言。
  bool get isWithinRange =>
      lowerMidi >= kMinMidi &&
      higherMidi <= kMaxMidi &&
      rootMidi >= kMinMidi &&
      rootMidi <= kMaxMidi;

  @override
  String toString() => 'RootNotePlan(root=$rootMidi, target=$targetMidi, '
      '${descending ? "desc" : "asc"}, $window)';
}
