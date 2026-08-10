import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/utils/app_logger.dart';

/// 应用生命周期观察者：切到后台 / 隐藏 / 销毁时自动停止播放（T23 验收 ①）。
///
/// 本类是「什么时候该停音频」的**唯一判定口径**（[shouldStop]）。应用根的
/// `AppLifecycleHandler` 直接复用本类做停音频，不再自己写一遍状态判断，
/// 避免两处规则漂移、也避免同一个 `stop()` 被两个观察者各调一次。
///
/// 用法二选一：
/// - **应用根**：由 `AppLifecycleHandler` 组合持有（不单独 [attach]），
///   由它统一注册唯一一个 [WidgetsBindingObserver]；
/// - **独立使用**：调用 [attach] 自行注册，[detach] 注销（仅停音频，
///   不做数据 flush）。
class AudioLifecycleObserver with WidgetsBindingObserver {
  /// 构造，持有音频服务引用。
  AudioLifecycleObserver(this.service);

  /// 被观察的音频服务。
  final AudioService service;

  bool _attached = false;

  /// 日志 tag。
  static const String logTag = 'AudioLifecycle';

  /// 需要立刻停音频的生命周期状态集合。
  ///
  /// - `paused`：Android/iOS 退到后台；
  /// - `hidden`：桌面端窗口隐藏 / 最小化（Windows 关窗前也会先走这里）；
  /// - `detached`：宿主 view 已销毁，进程即将退出。
  static const Set<AppLifecycleState> backgroundStates = <AppLifecycleState>{
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  };

  /// 该状态是否应当停止播放。
  static bool shouldStop(AppLifecycleState state) =>
      backgroundStates.contains(state);

  /// 是否已注册到 [WidgetsBinding]。
  bool get isAttached => _attached;

  /// 注册到 [WidgetsBinding]（幂等）。
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

  /// 按生命周期状态决定是否停止播放。
  Future<void> handle(AppLifecycleState state) async {
    if (!shouldStop(state)) {
      return;
    }
    await stopNow();
  }

  /// 立即停止播放；失败只记日志（退出路径上不允许抛异常）。
  ///
  /// 幂等：[AudioService.stop] 本身对「当前无播放」是安全的。
  Future<void> stopNow() async {
    try {
      await service.stop();
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'stop 失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 进入后台 / 隐藏 / 销毁：立即停止播放，避免后台漏音 & 资源占用。
    unawaited(handle(state));
  }
}
