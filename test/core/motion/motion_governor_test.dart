import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';

/// T03 验收项：`MotionGovernor` 双触发线（连续坏帧 / 滑窗 p90）+ 冷却的模拟测试。
///
/// 全部用注入的 `now` 与 `reportFrame` 驱动，不依赖真实帧回调，因此稳定、秒级完成。
void main() {
  // 生命周期测试会调用 start()/stop()，其内部访问 SchedulerBinding.instance，
  // 因此需要在非 widget 测试里显式初始化 binding。
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 可控时钟。
  late DateTime clock;
  DateTime now() => clock;

  setUp(() {
    clock = DateTime(2026);
  });

  MotionGovernor build({
    int windowSize = 10,
    int consecutiveBadFrameLimit = 30,
    Duration degradeSustain = const Duration(seconds: 3),
    Duration recoverSustain = const Duration(seconds: 10),
    Duration recoverCooldown = const Duration(seconds: 30),
  }) =>
      MotionGovernor(
        windowSize: windowSize,
        consecutiveBadFrameLimit: consecutiveBadFrameLimit,
        degradeSustain: degradeSustain,
        recoverSustain: recoverSustain,
        recoverCooldown: recoverCooldown,
        now: now,
      );

  void pump(
    MotionGovernor governor,
    int count,
    int frameMs, {
    Duration step = const Duration(milliseconds: 16),
  }) {
    for (int i = 0; i < count; i++) {
      clock = clock.add(step);
      governor.reportFrame(Duration(milliseconds: frameMs), at: clock);
    }
  }

  group('MotionDegradeStage 能力位', () {
    test('降级顺序：none → particlesReduced → blurDisabled → visualizerMinimal → motionReduced', () {
      expect(MotionDegradeStage.values, <MotionDegradeStage>[
        MotionDegradeStage.none,
        MotionDegradeStage.particlesReduced,
        MotionDegradeStage.blurDisabled,
        MotionDegradeStage.visualizerMinimal,
        MotionDegradeStage.motionReduced,
      ]);
    });

    test('各级别的能力位符合 PRD §3.10 降级动作表', () {
      expect(MotionDegradeStage.none.reducesParticles, isFalse);
      expect(MotionDegradeStage.none.allowsBackdropBlur, isTrue);
      expect(MotionDegradeStage.none.forcesMinimalVisualizer, isFalse);
      expect(MotionDegradeStage.none.forcesReducedMotion, isFalse);

      expect(MotionDegradeStage.particlesReduced.reducesParticles, isTrue);
      expect(MotionDegradeStage.particlesReduced.allowsBackdropBlur, isTrue);

      expect(MotionDegradeStage.blurDisabled.allowsBackdropBlur, isFalse);
      expect(MotionDegradeStage.blurDisabled.forcesMinimalVisualizer, isFalse);

      expect(MotionDegradeStage.visualizerMinimal.forcesMinimalVisualizer, isTrue);
      expect(MotionDegradeStage.visualizerMinimal.forcesReducedMotion, isFalse);

      expect(MotionDegradeStage.motionReduced.forcesReducedMotion, isTrue);
      expect(MotionDegradeStage.motionReduced.reducesParticles, isTrue);
      expect(MotionDegradeStage.motionReduced.allowsBackdropBlur, isFalse);
    });
  });

  group('触发线 1：连续坏帧', () {
    test('好帧下不降级', () {
      final MotionGovernor g = build();
      pump(g, 200, 8);
      expect(g.stage, MotionDegradeStage.none);
      expect(g.motionDegraded, isFalse);
      g.dispose();
    });

    test('连续 30 帧 > 16ms 立即降一级', () {
      final MotionGovernor g = build();
      pump(g, 29, 30);
      expect(g.stage, MotionDegradeStage.none, reason: '第 29 帧不该触发');
      expect(g.consecutiveBadFrames, 29);

      pump(g, 1, 30);
      expect(g.stage, MotionDegradeStage.particlesReduced);
      expect(g.consecutiveBadFrames, 0, reason: '触发后计数应清零');
      g.dispose();
    });

    test('中间插入一个好帧会重置连续计数', () {
      final MotionGovernor g = build();
      pump(g, 29, 30);
      pump(g, 1, 5);
      expect(g.consecutiveBadFrames, 0);
      pump(g, 29, 30);
      expect(g.stage, MotionDegradeStage.none);
      g.dispose();
    });

    test('恰好 16ms 不算坏帧（阈值是严格大于）', () {
      final MotionGovernor g = build();
      pump(g, 100, 16);
      expect(g.stage, MotionDegradeStage.none);
      expect(g.consecutiveBadFrames, 0);
      g.dispose();
    });

    test('持续卡顿会逐级降到 motionReduced 并停在那里', () {
      final MotionGovernor g = build();
      final List<MotionDegradeStage> seen = <MotionDegradeStage>[];
      g.addListener(() => seen.add(g.stage));

      for (int round = 0; round < 6; round++) {
        pump(g, 30, 40);
      }
      expect(g.stage, MotionDegradeStage.motionReduced);
      expect(g.motionDegraded, isTrue);
      expect(seen, <MotionDegradeStage>[
        MotionDegradeStage.particlesReduced,
        MotionDegradeStage.blurDisabled,
        MotionDegradeStage.visualizerMinimal,
        MotionDegradeStage.motionReduced,
      ]);
      g.dispose();
    });
  });

  group('触发线 2：滑窗 p90', () {
    test('窗口未填满时不做 p90 判定（冷启动不误判）', () {
      final MotionGovernor g = build(consecutiveBadFrameLimit: 10000);
      pump(g, 9, 50, step: const Duration(seconds: 1));
      expect(g.stage, MotionDegradeStage.none);
      g.dispose();
    });

    test('p90 > 20ms 持续 3s 后降级', () {
      final MotionGovernor g = build(consecutiveBadFrameLimit: 10000);
      // 先填满窗口。窗口填满那一帧即开始计 _p90BadSince。
      pump(g, 10, 25, step: const Duration(milliseconds: 500));
      expect(g.stage, MotionDegradeStage.none, reason: '刚超标还没满 3s');

      // 再推进 3s。
      pump(g, 6, 25, step: const Duration(milliseconds: 500));
      expect(g.stage, MotionDegradeStage.particlesReduced);
      g.dispose();
    });

    test('p90 超标未满 3s 就恢复正常，不降级', () {
      final MotionGovernor g = build(consecutiveBadFrameLimit: 10000);
      pump(g, 10, 25, step: const Duration(milliseconds: 500));
      pump(g, 4, 25, step: const Duration(milliseconds: 500)); // 累计 2s
      expect(g.stage, MotionDegradeStage.none);
      // 在 3s 期满之前把窗口冲刷成好帧，超标计时随之清零。
      pump(g, 20, 8, step: const Duration(milliseconds: 10));
      expect(g.stage, MotionDegradeStage.none);
      g.dispose();
    });

    test('p90 只受尾部 10% 影响：9 好 1 坏不触发降级', () {
      final MotionGovernor g = build(consecutiveBadFrameLimit: 10000);
      for (int i = 0; i < 100; i++) {
        clock = clock.add(const Duration(milliseconds: 500));
        g.reportFrame(Duration(milliseconds: i % 10 == 0 ? 60 : 5), at: clock);
      }
      expect(g.stage, MotionDegradeStage.none);
      g.dispose();
    });
  });

  group('恢复与冷却', () {
    test('降级后 p90 < 12ms 持续 10s 且过冷却期才回升一级', () {
      final MotionGovernor g = build(consecutiveBadFrameLimit: 30);
      pump(g, 30, 40); // 降到 particlesReduced
      expect(g.stage, MotionDegradeStage.particlesReduced);

      // 冷却期内（30s）即便帧率良好也不回升。
      pump(g, 40, 5, step: const Duration(milliseconds: 250)); // 10s
      expect(
        g.stage,
        MotionDegradeStage.particlesReduced,
        reason: '30s 冷却期未过，不应回升',
      );

      // 越过冷却期后继续好帧，满足 recoverSustain 即回升。
      pump(g, 120, 5, step: const Duration(milliseconds: 250)); // +30s
      expect(g.stage, MotionDegradeStage.none);
      g.dispose();
    });

    test('p90 落在 12~20ms 的中间带既不降级也不恢复', () {
      final MotionGovernor g = build(consecutiveBadFrameLimit: 30);
      pump(g, 30, 40);
      expect(g.stage, MotionDegradeStage.particlesReduced);
      pump(g, 400, 15, step: const Duration(milliseconds: 250)); // 100s 中间带
      expect(g.stage, MotionDegradeStage.particlesReduced);
      g.dispose();
    });

    test('回升是逐级的，不会一步回到 none', () {
      final MotionGovernor g = build(consecutiveBadFrameLimit: 30);
      pump(g, 30, 40);
      pump(g, 30, 40);
      expect(g.stage, MotionDegradeStage.blurDisabled);

      pump(g, 200, 5, step: const Duration(milliseconds: 250)); // 50s 好帧
      expect(g.stage, MotionDegradeStage.particlesReduced);
      g.dispose();
    });
  });

  group('生命周期', () {
    test('reset 清空级别与计数并通知监听者', () {
      final MotionGovernor g = build();
      pump(g, 30, 40);
      expect(g.stage, MotionDegradeStage.particlesReduced);

      int notified = 0;
      g.addListener(() => notified++);
      g.reset();
      expect(g.stage, MotionDegradeStage.none);
      expect(g.consecutiveBadFrames, 0);
      expect(notified, 1);
      g.dispose();
    });

    test('start / stop 切换 isListening', () {
      final MotionGovernor g = build();
      expect(g.isListening, isFalse);
      g.start();
      expect(g.isListening, isTrue);
      g.start(); // 幂等
      expect(g.isListening, isTrue);
      g.stop();
      expect(g.isListening, isFalse);
      g.stop(); // 幂等
      expect(g.isListening, isFalse);
      g.dispose();
    });

    test('dispose 会先 stop', () {
      final MotionGovernor g = build()..start();
      g.dispose();
      expect(g.isListening, isFalse);
    });

    test('非法构造参数触发断言', () {
      expect(() => MotionGovernor(windowSize: 0), throwsA(isA<AssertionError>()));
      expect(
        () => MotionGovernor(consecutiveBadFrameLimit: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
