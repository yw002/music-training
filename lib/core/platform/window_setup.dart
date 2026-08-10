import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/platform/platform_capabilities.dart';
import 'package:interval_ear/core/utils/app_logger.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';
import 'package:window_manager/window_manager.dart';

/// 窗口操作驱动（抽出接口，让 widget/unit test 不打 `window_manager`
/// 平台通道也能断言几何恢复与保存的行为）。
///
/// 生产实现是 [WindowManagerDriver]；测试传入内存替身即可。
abstract interface class WindowDriver {
  /// 当前窗口尺寸。
  Future<Size> getSize();

  /// 当前窗口左上角位置。
  Future<Offset> getPosition();

  /// 设置窗口尺寸。
  Future<void> setSize(Size size);

  /// 设置窗口左上角位置。
  Future<void> setPosition(Offset position);

  /// 是否拦截系统关窗（拦截后需自行 [destroy]）。
  Future<void> setPreventClose(bool value);

  /// 真正销毁窗口。
  Future<void> destroy();

  /// 注册窗口事件监听。
  void addListener(WindowListener listener);

  /// 注销窗口事件监听。
  void removeListener(WindowListener listener);
}

/// 走 `window_manager` 的默认驱动。
///
/// **只允许在应用启动路径上被实例化**（`AppBootstrap`）。页面 widget 一律
/// 不得直接持有它，否则 widget test 会打到桌面平台通道。
class WindowManagerDriver implements WindowDriver {
  /// 创建默认驱动。
  const WindowManagerDriver();

  @override
  Future<Size> getSize() => windowManager.getSize();

  @override
  Future<Offset> getPosition() => windowManager.getPosition();

  @override
  Future<void> setSize(Size size) => windowManager.setSize(size);

  @override
  Future<void> setPosition(Offset position) =>
      windowManager.setPosition(position);

  @override
  Future<void> setPreventClose(bool value) =>
      windowManager.setPreventClose(value);

  @override
  Future<void> destroy() => windowManager.destroy();

  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);

  @override
  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);
}

/// 桌面窗口几何的恢复与保存（架构 §2.8 T23 / 验收 ②）。
///
/// - 启动时从 [SettingsRepository.loadWindowGeometry] 读回上次的位置与尺寸，
///   在窗口 `show()` **之前**套用，避免出现「先默认尺寸、再跳到记忆尺寸」的
///   闪跳；记录非法（宽高小于最小值、含 NaN/Inf）时静默退回默认几何。
/// - 运行时监听 `onWindowResized` / `onWindowMoved`（两者都是「操作结束后」
///   触发一次，不是拖动过程中的高频事件），把当前几何写回设置。
/// - 关窗时（[onWindowClose]）先保存几何，再执行 [onClose] 收尾回调
///   （停音频 + flush），最后才真正 [WindowDriver.destroy] ——
///   这是架构 §8 风险点 7 要求的「Windows 关窗 flush 双重保险」的窗口侧一半，
///   另一半是 `AppLifecycleHandler` 监听的 `hidden` / `paused`。
///   两侧共用同一个幂等的 [onClose]，不会重复落盘。
class WindowGeometryController with WindowListener {
  /// 创建控制器。
  WindowGeometryController({
    required SettingsRepository settings,
    WindowDriver driver = const WindowManagerDriver(),
    Future<void> Function()? onClose,
  })  : _settings = settings,
        _driver = driver,
        _onClose = onClose;

  final SettingsRepository _settings;
  final WindowDriver _driver;
  final Future<void> Function()? _onClose;

  bool _attached = false;
  bool _saving = false;
  bool _closing = false;

  /// 日志 tag。
  static const String logTag = 'WindowSetup';

  /// 是否已注册窗口监听。
  bool get isAttached => _attached;

  /// 读取已保存的几何并套用到窗口。
  ///
  /// 无记录或记录非法时不做任何事（保留 `WindowOptions` 里的默认尺寸 + 居中）。
  Future<void> restore() async {
    final WindowGeometry? geometry = await _loadGeometry();
    if (geometry == null) {
      return;
    }
    if (!isRestorable(geometry)) {
      AppLogger.warning(
        '窗口几何记录非法，退回默认尺寸',
        tag: logTag,
      );
      return;
    }
    try {
      await _driver.setSize(Size(geometry.width, geometry.height));
      await _driver.setPosition(Offset(geometry.x, geometry.y));
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        '窗口几何恢复失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 读取当前窗口几何并写回设置。
  ///
  /// 并发保护：resize 与 move 可能几乎同时回调，重入时直接返回，
  /// 避免两次读窗口 + 两次原子写互相踩。
  Future<void> save() async {
    if (_saving) {
      return;
    }
    _saving = true;
    try {
      final Size size = await _driver.getSize();
      final Offset position = await _driver.getPosition();
      final WindowGeometry geometry = WindowGeometry(
        x: position.dx,
        y: position.dy,
        width: size.width,
        height: size.height,
      );
      if (!isRestorable(geometry)) {
        // 最小化时系统可能返回 0 尺寸，写进去会导致下次启动窗口不可见。
        return;
      }
      await _settings.saveWindowGeometry(geometry);
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        '窗口几何保存失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _saving = false;
    }
  }

  /// 注册窗口监听；配置了 [onClose] 时同时开启关窗拦截。
  Future<void> attach() async {
    if (_attached) {
      return;
    }
    _attached = true;
    _driver.addListener(this);
    if (_onClose == null) {
      return;
    }
    try {
      await _driver.setPreventClose(true);
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'setPreventClose 失败，关窗将不再等待数据落盘',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 注销窗口监听并撤销关窗拦截（幂等）。
  Future<void> detach() async {
    if (!_attached) {
      return;
    }
    _attached = false;
    _driver.removeListener(this);
    if (_onClose == null) {
      return;
    }
    try {
      await _driver.setPreventClose(false);
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'setPreventClose(false) 失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void onWindowResized() => unawaited(save());

  @override
  void onWindowMoved() => unawaited(save());

  @override
  void onWindowClose() => unawaited(handleClose());

  /// 关窗收尾：保存几何 → 执行收尾回调 → 销毁窗口（幂等，重入直接返回）。
  Future<void> handleClose() async {
    if (_closing) {
      return;
    }
    _closing = true;
    await save();
    try {
      await _onClose?.call();
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        '关窗收尾回调失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      await _driver.destroy();
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        '窗口销毁失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 几何记录是否可用于恢复。
  ///
  /// 判据：四个分量都是有限数；宽高不小于最小窗口尺寸，也不超过
  /// [AppConfig.desktopMaxRestoreExtent]（防止损坏记录把窗口撑到屏幕外）。
  static bool isRestorable(WindowGeometry geometry) {
    if (!geometry.x.isFinite ||
        !geometry.y.isFinite ||
        !geometry.width.isFinite ||
        !geometry.height.isFinite) {
      return false;
    }
    if (geometry.width < AppConfig.desktopMinWidth ||
        geometry.height < AppConfig.desktopMinHeight) {
      return false;
    }
    return geometry.width <= AppConfig.desktopMaxRestoreExtent &&
        geometry.height <= AppConfig.desktopMaxRestoreExtent;
  }

  Future<WindowGeometry?> _loadGeometry() async {
    try {
      return await _settings.loadWindowGeometry();
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        '窗口几何读取失败',
        tag: logTag,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}

/// 恢复窗口几何并挂上 resize / move / close 监听（T23 入口函数）。
///
/// 非桌面端（移动端 / Web）直接返回 `null`，**不触碰任何 `window_manager`
/// API**，因此在 macOS 宿主机上跑的 widget test 只要不显式传 desktop 能力位，
/// 就不会打平台通道。
///
/// 由 `AppBootstrap.configureDesktopWindow` 在 `windowManager.ensureInitialized()`
/// 之后、`show()` 之前调用。
Future<WindowGeometryController?> configureWindowGeometry(
  SettingsRepository settings, {
  WindowDriver driver = const WindowManagerDriver(),
  PlatformCapabilities? capabilities,
  Future<void> Function()? onClose,
}) async {
  final PlatformCapabilities caps = capabilities ?? PlatformCapabilities.current;
  if (!caps.hasWindowChrome) {
    return null;
  }
  final WindowGeometryController controller = WindowGeometryController(
    settings: settings,
    driver: driver,
    onClose: onClose,
  );
  await controller.restore();
  await controller.attach();
  return controller;
}

/// 可拖动窗口的自定义顶栏容器（T23）。
///
/// 隐藏系统标题栏时，用它包住自绘顶栏即可拖动窗口。两条平台约定：
/// - **macOS**：左侧留出 [AppConfig.macOSTrafficLightInset] 的内边距，
///   避免内容压在红绿灯按钮下面；
/// - **非桌面端**：直接返回 [child]，不引入任何手势与内边距（移动端没有
///   窗口可拖）。
///
/// 只做「拖动 + 内边距」，不画任何视觉 —— 视觉由调用方的顶栏组件负责。
class WindowDragArea extends StatelessWidget {
  /// 创建可拖动区域。
  const WindowDragArea({
    required this.child,
    this.capabilities,
    super.key,
  });

  /// 顶栏内容。
  final Widget child;

  /// 平台能力覆盖（测试用）；留空读 [PlatformCapabilities.current]。
  final PlatformCapabilities? capabilities;

  @override
  Widget build(BuildContext context) {
    final PlatformCapabilities caps =
        capabilities ?? PlatformCapabilities.current;
    if (!caps.hasWindowChrome) {
      return child;
    }
    return DragToMoveArea(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: caps.isApple ? AppConfig.macOSTrafficLightInset : 0,
        ),
        child: child,
      ),
    );
  }
}
