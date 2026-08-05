import 'package:interval_ear/features/training/domain/algorithm_constants.dart';

/// 根音可取值的闭区间 `[lo, hi]`（架构 §5.3）。
///
/// 单独抽成一个类而不是用 `(int, int)` 记录，是为了让「防泄露」这条最容易被
/// 后人改坏的约束有一个明确的挂载点：窗口是怎么算出来的、为什么和音程无关，
/// 全部写在这里，改动时无法绕过。
class RootWindow {
  /// 创建窗口。[lo] > [hi] 时抛 [ArgumentError]（说明上游算错了，不能静默兜底）。
  RootWindow(this.lo, this.hi) {
    if (lo > hi) {
      throw ArgumentError('RootWindow lo ($lo) must be <= hi ($hi)');
    }
  }

  /// 下界（含）。
  final int lo;

  /// 上界（含）。
  final int hi;

  /// 可取值个数。
  int get size => hi - lo + 1;

  /// 是否只有一个取值（固定根音）。
  bool get isSingleton => lo == hi;

  /// [value] 是否落在窗口内。
  bool contains(int value) => value >= lo && value <= hi;

  /// 把 [value] 夹进窗口。
  int clamp(int value) => value < lo ? lo : (value > hi ? hi : value);

  /// 与另一个窗口求交集；无交集返回 `null`。
  RootWindow? intersect(RootWindow other) {
    final newLo = lo > other.lo ? lo : other.lo;
    final newHi = hi < other.hi ? hi : other.hi;
    if (newLo > newHi) {
      return null;
    }
    return RootWindow(newLo, newHi);
  }

  /// **防泄露的统一安全窗口**（§5.3 的核心，T06 验收 2 就是在验它）。
  ///
  /// ## 为什么不能按音程动态算窗口
  ///
  /// 朴素做法是「保证 root 与 root+semitones 都在 [48, 84] 内」，于是
  /// `root ∈ [48, 84 - semitones]`。这会让**窗口宽度随音程变化**：
  /// 小二度可取 48–83（36 个值，均值 65.5），纯八度只能取 48–72
  /// （25 个值，均值 60）。用户听多了就会形成条件反射——
  /// 「根音听起来偏低 → 多半是大音程」，**在听清音程之前就能猜对**。
  /// 这是原规范点名要杜绝的信息泄露。
  ///
  /// ## 解法：窗口对所有音程取同一个
  ///
  /// 用**最大音程**（[kMaxSemitones] = 12）去反推窗口，然后 13 个音程共用：
  /// - 上行：`root ∈ [kMinMidi, kMaxMidi - 12] = [48, 72]`
  /// - 下行：目标音在下方，`root ∈ [kMinMidi + 12, kMaxMidi] = [60, 84]`
  /// - 和声：两音同时发声，按上行处理（根音是较低音）。
  ///
  /// 这样一来，**根音分布与音程完全独立**（互信息为 0），听根音高低推不出
  /// 任何关于音程的信息。代价是牺牲了一点音域宽度（36 → 25 个根音），
  /// 完全值得。
  ///
  /// [descending] 为 `true` 时返回下行窗口。
  static RootWindow safeWindow({required bool descending}) => descending
      ? RootWindow(kMinMidi + kMaxSemitones, kMaxMidi)
      : RootWindow(kMinMidi, kMaxMidi - kMaxSemitones);

  /// 固定根音模式的「窗口」（退化成单点 C4）。
  static RootWindow fixed() => RootWindow(kFixedRootMidi, kFixedRootMidi);

  /// 有限随机模式的窗口 C4–B4，再与安全窗口取交集。
  ///
  /// 取交集是必要的：C4–B4 = [60, 71] 在上行安全窗口 [48, 72] 内没问题，
  /// 但下行安全窗口是 [60, 84]，交集为 [60, 71]，同样安全。写成
  /// 「先取配置窗口，再和安全窗口求交」可以让将来调整 C4–B4 这个范围时，
  /// 不可能意外突破音域保护。
  static RootWindow limited({required bool descending}) {
    final configured = RootWindow(kWithinOctaveRootLo, kWithinOctaveRootHi);
    final safe = safeWindow(descending: descending);
    return configured.intersect(safe) ?? safe;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RootWindow && other.lo == lo && other.hi == hi);

  @override
  int get hashCode => Object.hash(lo, hi);

  @override
  String toString() => 'RootWindow([$lo, $hi], size=$size)';
}
