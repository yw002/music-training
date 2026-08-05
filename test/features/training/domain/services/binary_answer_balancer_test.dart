// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/utils/deterministic_random.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_pair.dart';
import 'package:interval_ear/features/training/domain/services/binary_answer_balancer.dart';

/// T06 验收 §5.4：二选一左右均衡——硬约束（无连续 3 次同侧）+ 软纠偏 + 随机。
void main() {
  final pair = IntervalPair(IntervalId.minorSixth, IntervalId.majorSixth);

  group('硬约束：无连续 3 次同侧', () {
    test('1000 题内不出现连续 3 次同一音程', () {
      final balancer = BinaryAnswerBalancer(pair: pair);
      final rng = Xorshift32Random(seed: 123);
      final sequence = <IntervalId>[];
      for (var i = 0; i < 1000; i++) {
        sequence.add(balancer.nextCorrect(rng));
      }
      for (var i = 2; i < sequence.length; i++) {
        final triple = <IntervalId>[
          sequence[i - 2],
          sequence[i - 1],
          sequence[i],
        ];
        final allLow = triple.every((id) => id == pair.low);
        final allHigh = triple.every((id) => id == pair.high);
        expect(allLow || allHigh, isFalse,
            reason: '位置 $i 出现连续 3 次同侧：$triple');
      }
    });
  });

  group('软纠偏：整体左右趋近 1:1', () {
    test('长序列左右计数偏差不超过 1 个小比例', () {
      final balancer = BinaryAnswerBalancer(pair: pair);
      final rng = Xorshift32Random(seed: 7);
      var low = 0;
      const total = 2000;
      for (var i = 0; i < total; i++) {
        final next = balancer.nextCorrect(rng);
        if (next == pair.low) {
          low++;
        }
      }
      final ratio = low / total;
      // 均衡目标 0.5，长序列应非常接近。
      expect(ratio, closeTo(0.5, 0.06));
    });
  });

  group('状态可快照/恢复', () {
    test('snapshot/restore 后行为一致', () {
      final balancer = BinaryAnswerBalancer(pair: pair);
      final rng = Xorshift32Random(seed: 55);
      final a = balancer.nextCorrect(rng);
      final b = balancer.nextCorrect(rng);
      final snap = balancer.snapshot();
      final c1 = balancer.nextCorrect(rng);

      final other = BinaryAnswerBalancer(pair: pair);
      other.restore(snap);
      final c2 = other.nextCorrect(rng);
      expect(c1, c2);
      expect([a, b, c1].whereType<IntervalId>().length, 3);
    });

    test('reset 清空历史', () {
      final balancer = BinaryAnswerBalancer(pair: pair);
      final rng = Xorshift32Random(seed: 3);
      balancer.nextCorrect(rng);
      balancer.nextCorrect(rng);
      expect(balancer.historyLength, 2);
      balancer.reset();
      expect(balancer.historyLength, 0);
    });
  });
}
