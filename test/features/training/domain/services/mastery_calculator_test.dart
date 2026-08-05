// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/services/mastery_calculator.dart';
import 'package:interval_ear/features/training/domain/stats/interval_statistics.dart';

/// T05 验收：§5.1 掌握度公式与分桶边界。
void main() {
  IntervalStatistics stats({
    required int total,
    required int correct,
    int uncertain = 0,
    List<bool>? recent,
    IntervalId interval = IntervalId.minorThird,
  }) =>
      IntervalStatistics(
        interval: interval,
        totalCount: total,
        correctCount: correct,
        uncertainCount: uncertain,
        recentOutcomes: recent ?? const <bool>[],
      );

  /// 参照实现：直接照抄 §5.1 的公式，与被测代码互为交叉验证。
  double reference({
    required int total,
    required int correct,
    int uncertain = 0,
    List<bool> recent = const <bool>[],
  }) {
    final n = total - uncertain;
    if (n <= 0) {
      return 0;
    }
    final rawAcc = correct / n;
    final recentAcc = recent.isEmpty
        ? rawAcc
        : recent.where((ok) => ok).length / recent.length;
    final conf = n / (n + kMasteryConfidenceK);
    final blended = (1 - kRecentWeight) * rawAcc + kRecentWeight * recentAcc;
    return (blended * conf).clamp(0.0, 1.0);
  }

  group('compute（§5.1）', () {
    test('零历史返回 0', () {
      expect(MasteryCalculator.compute(stats(total: 0, correct: 0)), 0);
    });

    test('「练 2 题全对」仍落在 weak 桶', () {
      final s = stats(total: 2, correct: 2, recent: const <bool>[true, true]);
      final mastery = MasteryCalculator.compute(s);
      expect(mastery, closeTo(2 / 7, 1e-9));
      expect(MasteryCalculator.bucketOf(mastery: mastery), MasteryBucket.weak);
    });

    test('与参照公式逐点一致', () {
      final cases = <List<int>>[
        <int>[1, 1, 0],
        <int>[5, 3, 0],
        <int>[10, 9, 1],
        <int>[30, 28, 2],
        <int>[100, 95, 5],
      ];
      for (final c in cases) {
        final recent = <bool>[
          for (var i = 0; i < (c[0] < kRecentWindow ? c[0] : kRecentWindow); i++)
            i < c[1],
        ];
        final actual = MasteryCalculator.compute(
          stats(total: c[0], correct: c[1], uncertain: c[2], recent: recent),
        );
        final expected = reference(
          total: c[0],
          correct: c[1],
          uncertain: c[2],
          recent: recent,
        );
        expect(actual, closeTo(expected, 1e-12), reason: '用例 $c');
      }
    });

    test('全部不确定时 n=0 → mastery 0，不产生 NaN', () {
      final s = stats(total: 8, correct: 0, uncertain: 8);
      final mastery = MasteryCalculator.compute(s);
      expect(mastery, 0);
      expect(mastery.isNaN, isFalse);
    });

    test('大样本全对趋近 1', () {
      final s = stats(
        total: 200,
        correct: 200,
        recent: List<bool>.filled(kRecentWindow, true),
      );
      final mastery = MasteryCalculator.compute(s);
      expect(mastery, greaterThan(0.95));
      expect(mastery, lessThanOrEqualTo(1.0));
    });
  });

  group('bucketOf 边界（验收：0.4999 / 0.7499 / 0.8999）', () {
    test('0.4999 → weak，0.5 → medium', () {
      expect(MasteryCalculator.bucketOf(mastery: 0.4999), MasteryBucket.weak);
      expect(MasteryCalculator.bucketOf(mastery: 0.5), MasteryBucket.medium);
    });

    test('0.7499 → medium，0.75 → strong', () {
      expect(MasteryCalculator.bucketOf(mastery: 0.7499), MasteryBucket.medium);
      expect(MasteryCalculator.bucketOf(mastery: 0.75), MasteryBucket.strong);
    });

    test('0.8999 → strong，0.9 → mastered', () {
      expect(MasteryCalculator.bucketOf(mastery: 0.8999), MasteryBucket.strong);
      expect(MasteryCalculator.bucketOf(mastery: 0.9), MasteryBucket.mastered);
    });

    test('极端值不越界', () {
      expect(MasteryCalculator.bucketOf(mastery: 0), MasteryBucket.weak);
      expect(MasteryCalculator.bucketOf(mastery: 1), MasteryBucket.mastered);
    });
  });

  group('bucketize', () {
    test('每个音程只落一个桶，全部桶键存在', () {
      final all = <IntervalStatistics>[
        stats(total: 0, correct: 0, interval: IntervalId.minorSecond),
        stats(
          total: 100,
          correct: 100,
          recent: List<bool>.filled(kRecentWindow, true),
          interval: IntervalId.perfectOctave,
        ),
      ];
      final buckets = MasteryCalculator.bucketize(all);
      expect(buckets.keys.toSet(), MasteryBucket.values.toSet());
      expect(buckets[MasteryBucket.weak], contains(IntervalId.minorSecond));
      expect(
        buckets[MasteryBucket.mastered],
        contains(IntervalId.perfectOctave),
      );
      final totalAssigned =
          buckets.values.fold<int>(0, (acc, set) => acc + set.length);
      expect(totalAssigned, all.length);
    });
  });
}
