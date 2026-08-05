import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'package:interval_ear/core/utils/app_logger.dart';
import 'package:interval_ear/core/utils/math_utils.dart';

/// 看门狗的降级级别，按 PRD §3.10 的「降级动作（按序）」定义。
///
/// 逐级降级而不是一步到位的原因：粒子和玻璃拟态是最贵也最不影响信息传达的两项，
/// 先砍它们通常就能把帧率救回来；把整体动效降为 `reduced` 是最后手段，因为那会
/// 改变用户能感知到的交互质感。
enum MotionDegradeStage {
  /// 未降级。
  none,

  /// ① 粒子上限 48 → 16。
  particlesReduced,

  /// ② `BackdropFilter` sigma → 0，改用不透明底。
  blurDisabled,

  /// ③ 可视化方案强制切到 `minimal`（`M-10`）。
  visualizerMinimal,

  /// ④ 整体降为 `MotionLevel.reduced`。
  motionReduced;

  /// 是否已经开始限制粒子数。
  bool get reducesParticles => index >= MotionDegradeStage.particlesReduced.index;

  /// 是否仍允许 `BackdropFilter`。
  bool get allowsBackdropBlur => index < MotionDegradeStage.blurDisabled.index;

  /// 是否强制极简可视化。
  bool get forcesMinimalVisualizer =>
      index >= MotionDegradeStage.visualizerMinimal.index;

  /// 是否要求把整体动效降为 `reduced`。
  bool get forcesReducedMotion =>
      index >= MotionDegradeStage.motionReduced.index;

  /// 下一级（已在最深一级则返回自身）。
  MotionDegradeStage get next => index + 1 < MotionDegradeStage.values.length
      ? MotionDegradeStage.values[index + 1]
      : this;

  /// 上一级（已在 [none] 则返回自身）。
  MotionDegradeStage get previous =>
      index > 0 ? MotionDegradeStage.values[index - 1] : this;
}

/// 帧性能看门狗（PRD §3.10）。
///
/// 两条独立的降级触发线：
/// 1. **连续坏帧线**：连续 [consecutiveBadFrameLimit] 帧的 build+raster 超过
///    [badFrameThreshold]。这条线响应快，用于抓「一进某个页面就卡死」。
/// 2. **滑窗 p90 线**：滑动窗口 [windowSize] 帧的 p90 持续超过
///    [p90DegradeThreshold] 达 [degradeSustain]。这条线抗抖动，用于抓持续性劣化。
///
/// 恢复条件更严格（p90 持续低于 [p90RecoverThreshold] 达 [recoverSustain]，
/// 且距上次级别变化 ≥ [recoverCooldown]），避免在阈值附近反复横跳。
///
/// 全过程只打日志，**不弹任何提示打扰用户**。
class MotionGovernor extends ChangeNotifier {
  /// 创建看门狗。所有阈值都可注入，便于用短窗口做单测。
  MotionGovernor({
    this.windowSize = 60,
    this.badFrameThreshold = const Duration(milliseconds: 16),
    this.consecutiveBadFrameLimit = 30,
    this.p90DegradeThreshold = const Duration(milliseconds: 20),
    this.p90RecoverThreshold = const Duration(milliseconds: 12),
    this.degradeSustain = const Duration(seconds: 3),
    this.recoverSustain = const Duration(seconds: 10),
    this.recoverCooldown = const Duration(seconds: 30),
    DateTime Function()? now,
  })  : assert(windowSize > 0, 'windowSize must be positive'),
        assert(
          consecutiveBadFrameLimit > 0,
          'consecutiveBadFrameLimit must be positive',
        ),
        _now = now ?? DateTime.now;

  /// 日志标签。
  static const String logTag = 'MotionGovernor';

  /// 滑动窗口帧数。
  final int windowSize;

  /// 单帧「坏帧」判定阈值。
  final Duration badFrameThreshold;

  /// 连续坏帧多少帧后立即降级。
  final int consecutiveBadFrameLimit;

  /// p90 降级阈值。
  final Duration p90DegradeThreshold;

  /// p90 恢复阈值。
  final Duration p90RecoverThreshold;

  /// p90 超标需持续多久才降级。
  final Duration degradeSustain;

  /// p90 达标需持续多久才恢复。
  final Duration recoverSustain;

  /// 两次级别变化之间的最小间隔。
  final Duration recoverCooldown;

  final DateTime Function() _now;
  final List<int> _window = <int>[];

  MotionDegradeStage _stage = MotionDegradeStage.none;
  int _consecutiveBadFrames = 0;
  DateTime? _p90BadSince;
  DateTime? _p90GoodSince;
  DateTime? _lastStageChangeAt;
  bool _listening = false;

  /// 当前降级级别。
  MotionDegradeStage get stage => _stage;

  /// 是否已经降到「整体 reduced」。`MotionLevelResolver` 读的就是这个。
  bool get motionDegraded => _stage.forcesReducedMotion;

  /// 是否正在监听真实帧回调。
  bool get isListening => _listening;

  /// 当前窗口内的 p90 帧耗时（毫秒）。窗口为空时返回 0。
  double get currentP90Ms => MathUtils.percentile(_window, 0.9);

  /// 当前连续坏帧数。
  int get consecutiveBadFrames => _consecutiveBadFrames;

  /// 开始监听 `SchedulerBinding` 的帧时序回调。重复调用无副作用。
  void start() {
    if (_listening) {
      return;
    }
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    AppLogger.debug('started', tag: logTag);
  }

  /// 停止监听。
  void stop() {
    if (!_listening) {
      return;
    }
    _listening = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    AppLogger.debug('stopped', tag: logTag);
  }

  /// 清空统计并回到未降级状态。
  void reset() {
    _window.clear();
    _stage = MotionDegradeStage.none;
    _consecutiveBadFrames = 0;
    _p90BadSince = null;
    _p90GoodSince = null;
    _lastStageChangeAt = null;
    notifyListeners();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      reportFrame(timing.buildDuration + timing.rasterDuration);
    }
  }

  /// 上报一帧的 build+raster 总耗时。
  ///
  /// 单测直接调这个方法模拟卡顿，不需要真的跑出掉帧。
  void reportFrame(Duration frameCost, {DateTime? at}) {
    final now = at ?? _now();
    _window.add(frameCost.inMicroseconds);
    if (_window.length > windowSize) {
      _window.removeRange(0, _window.length - windowSize);
    }

    if (frameCost > badFrameThreshold) {
      _consecutiveBadFrames++;
    } else {
      _consecutiveBadFrames = 0;
    }

    // 触发线 1：连续坏帧。
    if (_consecutiveBadFrames >= consecutiveBadFrameLimit) {
      _consecutiveBadFrames = 0;
      _degrade(
        now,
        'consecutive $consecutiveBadFrameLimit frames over '
        '${badFrameThreshold.inMilliseconds}ms',
      );
      return;
    }

    // 触发线 2 / 恢复线：滑窗 p90。窗口未填满前不做 p90 判定，避免冷启动误判。
    if (_window.length < windowSize) {
      return;
    }
    final p90Micros = MathUtils.percentile(_window, 0.9);
    if (p90Micros > p90DegradeThreshold.inMicroseconds) {
      _p90GoodSince = null;
      final since = _p90BadSince ??= now;
      if (now.difference(since) >= degradeSustain) {
        _p90BadSince = null;
        _degrade(
          now,
          'p90 ${(p90Micros / 1000).toStringAsFixed(1)}ms over '
          '${p90DegradeThreshold.inMilliseconds}ms for '
          '${degradeSustain.inSeconds}s',
        );
      }
      return;
    }

    _p90BadSince = null;
    if (p90Micros < p90RecoverThreshold.inMicroseconds) {
      final since = _p90GoodSince ??= now;
      if (now.difference(since) >= recoverSustain) {
        _p90GoodSince = null;
        _recover(now, 'p90 ${(p90Micros / 1000).toStringAsFixed(1)}ms');
      }
    } else {
      _p90GoodSince = null;
    }
  }

  void _degrade(DateTime now, String reason) {
    final next = _stage.next;
    if (next == _stage) {
      return;
    }
    _stage = next;
    _lastStageChangeAt = now;
    AppLogger.warning(
      'degraded to ${next.name} ($reason)',
      tag: logTag,
    );
    notifyListeners();
  }

  void _recover(DateTime now, String reason) {
    if (_stage == MotionDegradeStage.none) {
      return;
    }
    final last = _lastStageChangeAt;
    if (last != null && now.difference(last) < recoverCooldown) {
      return;
    }
    final previous = _stage.previous;
    _stage = previous;
    _lastStageChangeAt = now;
    AppLogger.info(
      'recovered to ${previous.name} ($reason)',
      tag: logTag,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
