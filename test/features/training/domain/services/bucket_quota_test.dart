// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/services/bucket_quota.dart';

/// T06 验收 §5.2：配额 50/25/15/10、空桶顺延、weak 保底、余数归 weak。
void main() {
  group('权重', () {
    test('四桶权重之和 = 1', () {
      final sum = BucketQuota.weights.values.fold<double>(
        0,
        (acc, w) => acc + w,
      );
      expect(sum, closeTo(1.0, 1e-12));
    });
  });

  group('allocate 配额分配', () {
    test('20 题标准分配：10/5/3/2', () {
      final quota = BucketQuota.allocate(
        totalQuestions: 20,
        nonEmpty: <MasteryBucket>{
          MasteryBucket.weak,
          MasteryBucket.medium,
          MasteryBucket.strong,
          MasteryBucket.mastered,
        },
      );
      expect(quota.of(MasteryBucket.weak), 10);
      expect(quota.of(MasteryBucket.medium), 5);
      expect(quota.of(MasteryBucket.strong), 3);
      expect(quota.of(MasteryBucket.mastered), 2);
      expect(quota.total, 20);
    });

    test('空桶顺延：mastered 空 → 其份额归 strong', () {
      final quota = BucketQuota.allocate(
        totalQuestions: 20,
        nonEmpty: <MasteryBucket>{
          MasteryBucket.weak,
          MasteryBucket.medium,
          MasteryBucket.strong,
        },
      );
      // nonEmpty = {weak, medium, strong}，mastered 空 → 权重归一化：
      // weak 0.5/0.9, medium 0.25/0.9, strong 0.15/0.9；20 题取整后余 1 归 weak。
      expect(quota.of(MasteryBucket.weak), 12);
      expect(quota.of(MasteryBucket.medium), 5);
      expect(quota.of(MasteryBucket.strong), 3);
      expect(quota.of(MasteryBucket.mastered), 0);
      expect(quota.total, 20);
    });

    test('只差 weak 非空时，其它份额全部顺延给 weak', () {
      final quota = BucketQuota.allocate(
        totalQuestions: 20,
        nonEmpty: <MasteryBucket>{MasteryBucket.weak},
      );
      expect(quota.of(MasteryBucket.weak), 20);
      expect(quota.total, 20);
    });

    test('weak 保底：极小题数也要给 weak 至少 1', () {
      final quota = BucketQuota.allocate(
        totalQuestions: 1,
        nonEmpty: <MasteryBucket>{
          MasteryBucket.weak,
          MasteryBucket.medium,
          MasteryBucket.strong,
          MasteryBucket.mastered,
        },
      );
      expect(quota.of(MasteryBucket.weak), greaterThanOrEqualTo(1));
      expect(quota.total, 1);
    });

    test('零题数返回全 0', () {
      final quota = BucketQuota.allocate(
        totalQuestions: 0,
        nonEmpty: MasteryBucket.values.toSet(),
      );
      expect(quota.total, 0);
      for (final bucket in MasteryBucket.values) {
        expect(quota.of(bucket), 0);
      }
    });

    test('配额总和恒等于题数（多组随机抽样）', () {
      for (var total = 1; total <= 40; total++) {
        final nonEmpty = <MasteryBucket>{
          MasteryBucket.weak,
          MasteryBucket.medium,
          MasteryBucket.strong,
          MasteryBucket.mastered,
        };
        final quota = BucketQuota.allocate(totalQuestions: total, nonEmpty: nonEmpty);
        expect(quota.total, total, reason: 'total=$total');
      }
    });
  });
}
