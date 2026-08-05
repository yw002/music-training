import 'package:flutter/widgets.dart';

import 'package:interval_ear/core/audio/audio_service.dart';

/// 应用生命周期观察者：切到后台 / 销毁时自动停止播放，避免声音在后台继续响。
///
/// 通过 [WidgetsBindingObserver] 监听 [AppLifecycleState]，在 `paused` / `detached`
/// 时调用 [AudioService.stop()]。由 UI 层在 `initState` `attach()`、`dispose`
/// `detach()`。
class AudioLifecycleObserver with WidgetsBindingObserver {
  /// 构造，持有音频服务引用。
  AudioLifecycleObserver(this.service);

  /// 被观察的音频服务。
  final AudioService service;

  /// 注册到 [WidgetsBinding]。
  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// 从 [WidgetsBinding] 注销。
  void detach() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 进入后台或应用销毁：立即停止播放，避免后台漏音 & 资源占用。
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      service.stop();
    }
  }
}
