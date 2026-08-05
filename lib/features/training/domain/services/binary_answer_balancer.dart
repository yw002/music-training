import 'dart:math' as math;

import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';

/// 二选一「正确答案落在哪一侧」的均衡器（架构 §5.4）。
///
/// ## 要解决的问题
///
/// 二选一强化里，如果正确答案随机落在两侧，短期内很容易出现「连着 5 题都是
/// 左边」。用户很快会发现规律，改用「上一题是左边，这题多半还是左边」的
/// 元策略蒙分，训练就废了。反过来，如果强制严格左右交替（LRLRLR），
/// 规律更明显、更容易被利用。
///
/// ## 解法：硬约束 + 软纠偏
///
/// 1. **硬约束**：同一侧连续出现达到 [kBalanceMaxRun]（2）次后，下一题**必须**
///    换边。这直接掐死「连续 3 次同侧」，用户没法靠惯性蒙。
/// 2. **软纠偏**：在最近 [kBalanceWindow]（6）题的滑动窗口里，若两侧数量差
///    达到 [kBalanceDeviationThreshold]（2），则**强制**补少的那一侧。
/// 3. 以上都不触发时，才**随机**掷硬币。
///
/// 硬约束保证了「不可预测性的下界」，软纠偏保证了「长期 1:1 的均衡」，
/// 随机保证了「在允许范围内不可预测」。三者缺一：只有随机会连出；
/// 只有硬约束会退化成 LLRRLLRR 的周期；只有软纠偏在窗口内仍可能连出 3 次。
///
/// ## 状态
///
/// 本类**有状态**（要记住最近的历史），因此不是 abstract final。每场二选一
/// 训练创建一个实例，随会话生命周期存活。状态可通过 [snapshot] / [restore]
/// 保存与恢复，配合 `Xorshift32Random.state` 实现「中断后完整复现出题序列」。
class BinaryAnswerBalancer {
  /// 为音程对 [pair] 创建一个均衡器。
  BinaryAnswerBalancer({required IntervalPair pair})
      : pair = pair.normalized(),
        _history = <bool>[];

  /// 焦点音程对（已规范化）。
  final IntervalPair pair;

  /// 最近若干题「正确答案是否落在 low 侧」的历史，末尾最新。
  ///
  /// 只保留 [kBalanceWindow] 条：更早的记录对当前决策没有影响，留着只会
  /// 让窗口统计失真。
  final List<bool> _history;

  /// 历史长度（不超过 [kBalanceWindow]）。
  int get historyLength => _history.length;

  /// 当前窗口内落在 low 侧的次数。
  int get lowCount {
    var count = 0;
    for (final isLow in _history) {
      if (isLow) {
        count++;
      }
    }
    return count;
  }

  /// 当前窗口内落在 high 侧的次数。
  int get highCount => _history.length - lowCount;

  /// 末尾连续同侧的次数（0 表示还没有历史）。
  int get currentRun {
    if (_history.isEmpty) {
      return 0;
    }
    final last = _history.last;
    var run = 0;
    for (var i = _history.length - 1; i >= 0; i--) {
      if (_history[i] != last) {
        break;
      }
      run++;
    }
    return run;
  }

  /// 决定下一题的正确答案落在哪一侧，并把结果记入历史。
  ///
  /// 返回具体的 [IntervalId]（[IntervalPair.low] 或 [IntervalPair.high]），
  /// 调用方直接拿去当正确答案。
  IntervalId nextCorrect(math.Random random) {
    final isLow = _decideIsLow(random);
    _push(isLow);
    return isLow ? pair.low : pair.high;
  }

  /// 只做决策、不记历史（用于预演与测试）。
  bool peekIsLow(math.Random random) => _decideIsLow(random);

  /// 手动记录一次结果（用于「答案由外部决定」的场景，如加练插题）。
  void record(IntervalId correct) {
    if (!pair.contains(correct)) {
      throw ArgumentError(
        'correct (${correct.storageId}) is not part of pair ${pair.key()}',
      );
    }
    _push(correct == pair.low);
  }

  bool _decideIsLow(math.Random random) {
    // 1) 硬约束：连续同侧已达上限，必须换边。
    if (_history.isNotEmpty && currentRun >= kBalanceMaxRun) {
      return !_history.last;
    }

    // 2) 软纠偏：窗口内偏差达阈值，补少的一侧。
    final deviation = lowCount - highCount;
    if (deviation >= kBalanceDeviationThreshold) {
      return false; // low 偏多，补 high。
    }
    if (-deviation >= kBalanceDeviationThreshold) {
      return true; // high 偏多，补 low。
    }

    // 3) 允许范围内随机。用 nextDouble 与目标占比比较，而不是 nextBool()，
    //    这样将来想把目标占比调成 0.45 之类的值时无需改结构。
    return random.nextDouble() < kBalanceTargetRatio;
  }

  void _push(bool isLow) {
    _history.add(isLow);
    if (_history.length > kBalanceWindow) {
      _history.removeRange(0, _history.length - kBalanceWindow);
    }
  }

  /// 导出内部状态（供「保存进度」用）。
  List<bool> snapshot() => List<bool>.unmodifiable(_history);

  /// 从 [snapshot] 恢复状态。超长输入只保留最后 [kBalanceWindow] 条。
  void restore(List<bool> history) {
    _history
      ..clear()
      ..addAll(
        history.length <= kBalanceWindow
            ? history
            : history.sublist(history.length - kBalanceWindow),
      );
  }

  /// 清空历史。
  void reset() => _history.clear();

  @override
  String toString() => 'BinaryAnswerBalancer(${pair.key()}, '
      'low=$lowCount, high=$highCount, run=$currentRun)';
}
