import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:interval_ear/core/audio/audio_lifecycle_observer.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/utils/app_logger.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';

/// 「进行中训练会话」的应用级登记处（T23 验收 ⑥）。
///
/// 训练 Cubit 是**页面级**对象，而生命周期处理器是**进程级**的：两者无法直接
/// 互相引用。这里用一个极薄的登记处把它们解耦 —— 训练开始时 [begin]，结算或
/// 关闭时 [clear]，[AppLifecycleHandler] 只读 [current] 判断「退到后台时是否
/// 有一组没打完的训练」。
///
/// 故意**不**做成全局单例：实例由 `AppDependencies` 持有并注入，测试可以各自
/// 建一个干净的登记处，不会互相串味。
class ActiveSessionRegistry {
  /// 创建一个空登记处。
  ActiveSessionRegistry();

  TrainingSession? _current;

  /// 当前进行中的会话；无进行中的训练时为 `null`。
  TrainingSession? get current => _current;

  /// 是否有一组尚未结算的训练。
  bool get hasActiveSession => _current != null && !_current!.isFinished();

  /// 登记一组刚开始（或进度有更新）的训练。
  void begin(TrainingSession session) {
    _current = session;
  }

  /// 更新进行中会话的快照（进度变化时调用，语义等同 [begin]）。
  void update(TrainingSession session) {
    _current = session;
  }

  /// 清除登记（正常结算 / 已落盘 aborted / Cubit 关闭时调用）。
  void clear() {
    _current = null;
  }
}

/// 应用级生命周期处理器（架构 §2.8 T23）。
///
/// 职责（验收 ① + ⑥）：进入 `paused` / `hidden` / `detached`，或桌面端收到
/// 关窗回调时，依次执行
///
/// 1. [AudioService.stop]：立刻停声，避免后台漏音（复用
///    [AudioLifecycleObserver] 的判定与停止逻辑，**不重复实现**）；
/// 2. 若有进行中的训练会话 → 标记 `aborted` 后经
///    [TrainingRepository.abortSession] 落盘（只进流水、不进统计，
///    不污染正确率）；
/// 3. [TrainingRepository.flush]：把内存统计强制写进 `stats.json`。
///
/// 设计约束：
/// - **只允许挂在 App 根**（`IntervalEarApp`），绝不能挂进任何页面 widget，
///   否则页面 widget test 会因为进程级副作用而互相干扰；
/// - [handleShutdown] **幂等**：Windows 关窗时 `window_manager` 回调与
///   `WidgetsBinding` 的 `hidden` 可能双双触发（架构 §8 风险点 7 的双重保险），
///   重复调用只会真正执行一次；
/// - 任何一步失败都只记日志，不抛出 —— 退出路径上抛异常只会让用户丢数据。
class AppLifecycleHandler with WidgetsBindingObserver {
  /// 创建处理器。
  ///
  /// [audio] 与 [repository] 为进程级单例；[sessions] 留空时自建一个空登记处
  /// （此时验收 ⑥ 相当于「永远没有进行中的会话」，仅停音频 + flush）。
  AppLifecycleHandler({
    required AudioService audio,
    required TrainingRepository repository,
    ActiveSessionRegistry? sessions,
  })  : _audio = AudioLifecycleObserver(audio),
        _repository = repository,
        sessions = sessions ?? ActiveSessionRegistry();

  final AudioLifecycleObserver _audio;
  final TrainingRepository _repository;

  /// 进行中会话登记处。
  final ActiveSessionRegistry sessions;

  Future<void>? _inFlight;
  bool _attached = false;

  /// 日志 tag。
  static const String logTag = 'AppLifecycle';

  /// 是否已注册到 [WidgetsBinding]。
  bool get isAttached => _attached;

  /// 注册到 [WidgetsBinding]（只在 App 根调用，幂等）。
  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// 从 [WidgetsBinding] 注销（幂等）。
  void detach() {
    if (!_attached) {
      return;
    }
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 判定口径与 AudioLifecycleObserver 完全一致，避免两处规则漂移。
    if (AudioLifecycleObserver.shouldStop(state)) {
      unawaited(handleShutdown());
    }
  }

  /// 执行「退出前收尾」：停音频 → 标记 aborted 落盘 → flush。
  ///
  /// 幂等：并发或重复调用返回**同一个** [Future]（identical），只真正执行一次。
  /// 收尾结束后守卫会自动复位，进程没退出时的下一轮后台切换仍会正常执行。
  Future<void> handleShutdown() {
    final Future<void>? running = _inFlight;
    if (running != null) {
      return running;
    }
    // 先把清理挂进 whenComplete 再赋值给 _inFlight，保证「对外返回的 future」
    // 与「守卫里存的 future」是同一个对象。
    final Future<void> started = _runShutdown().whenComplete(() {
      _inFlight = null;
    });
    _inFlight = started;
    return started;
  }

  Future<void> _runShutdown() async {
    await _audio.stopNow();
    await _abortActiveSession();
    await _flush();
  }

  /// 把进行中的会话标记为 `aborted` 并落盘（不计入统计）。
  Future<void> _abortActiveSession() async {
    final TrainingSession? active = sessions.current;
    if (active == null || active.isFinished() || active.aborted) {
      // 没有进行中的训练，或已经结算/已标记，无需重复落盘。
      sessions.clear();
      return;
    }
    try {
      await _repository.abortSession(active.copyWith(aborted: true));
      AppLogger.info(
        'session ${active.sessionId} 中途退出，已标记 aborted',
        tag: logTag,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'abortSession 失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
    sessions.clear();
  }

  Future<void> _flush() async {
    try {
      await _repository.flush();
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'flush 失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
