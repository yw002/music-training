// T23 验收 ②：桌面窗口几何的恢复与保存。
//
// 最重要的一条（测试安全）：**非桌面平台一律不触碰 `window_manager`**。
// 本文件跑在 macOS 宿主机上，如果实现里漏了平台守卫，`_FakeWindowDriver`
// 的调用计数会立刻暴露出来 —— 生产驱动才会真的打平台通道。
//
// 其余覆盖：几何合法性判据、resize/move 回写、最小化时的 0 尺寸保护、
// 关窗链路（保存 → 收尾回调 → destroy）与其幂等性。

import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/platform/platform_capabilities.dart';
import 'package:interval_ear/core/platform/window_setup.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';
import 'package:window_manager/window_manager.dart';

/// 内存窗口驱动替身：记录每一次调用，绝不打平台通道。
class _FakeWindowDriver implements WindowDriver {
  _FakeWindowDriver({
    Size size = const Size(1024, 720),
    Offset position = const Offset(120, 80),
  })  : _size = size,
        _position = position;

  Size _size;
  Offset _position;

  final List<Size> setSizeCalls = <Size>[];
  final List<Offset> setPositionCalls = <Offset>[];
  final List<bool> preventCloseCalls = <bool>[];
  final List<WindowListener> listeners = <WindowListener>[];
  int destroyCalls = 0;

  /// 任一调用总数，用于断言「完全没碰过窗口」。
  int get totalCalls =>
      setSizeCalls.length +
      setPositionCalls.length +
      preventCloseCalls.length +
      listeners.length +
      destroyCalls;

  @override
  Future<Size> getSize() async => _size;

  @override
  Future<Offset> getPosition() async => _position;

  @override
  Future<void> setSize(Size size) async {
    setSizeCalls.add(size);
    _size = size;
  }

  @override
  Future<void> setPosition(Offset position) async {
    setPositionCalls.add(position);
    _position = position;
  }

  @override
  Future<void> setPreventClose(bool value) async {
    preventCloseCalls.add(value);
  }

  @override
  Future<void> destroy() async {
    destroyCalls++;
  }

  @override
  void addListener(WindowListener listener) => listeners.add(listener);

  @override
  void removeListener(WindowListener listener) => listeners.remove(listener);
}

/// 只关心窗口几何的设置仓储替身。
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.stored});

  /// 已保存的几何（`null` 表示首次启动无记录）。
  WindowGeometry? stored;

  /// 读取时抛异常（模拟设置文件损坏）。
  bool throwOnLoad = false;

  final List<WindowGeometry> saved = <WindowGeometry>[];

  @override
  Future<WindowGeometry?> loadWindowGeometry() async {
    if (throwOnLoad) {
      throw const FormatException('broken settings');
    }
    return stored;
  }

  @override
  Future<void> saveWindowGeometry(WindowGeometry geometry) async {
    saved.add(geometry);
    stored = geometry;
  }

  @override
  Future<AppSettings> load() async => AppSettings.defaults;

  @override
  Future<void> save(AppSettings settings) async {}

  @override
  Future<TrainingConfig> loadLastFreeConfig() async => TrainingConfig.defaults;

  @override
  Future<void> saveLastFreeConfig(TrainingConfig config) async {}
}

WindowGeometry _geometry({
  double x = 100,
  double y = 60,
  double width = 1200,
  double height = 800,
}) =>
    WindowGeometry(x: x, y: y, width: width, height: height);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PlatformCapabilities.debugOverride(null));

  group('configureWindowGeometry 平台守卫（测试安全）', () {
    test('移动端返回 null，且完全不碰窗口驱动', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final _FakeSettingsRepository settings =
          _FakeSettingsRepository(stored: _geometry());

      final WindowGeometryController? controller =
          await configureWindowGeometry(
        settings,
        driver: driver,
        capabilities: const PlatformCapabilities.mobile(),
      );

      expect(controller, isNull);
      expect(driver.totalCalls, 0);
      expect(settings.saved, isEmpty);
    });

    test('Web 同样返回 null', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final WindowGeometryController? controller =
          await configureWindowGeometry(
        _FakeSettingsRepository(stored: _geometry()),
        driver: driver,
        capabilities: const PlatformCapabilities.web(),
      );

      expect(controller, isNull);
      expect(driver.totalCalls, 0);
    });

    test('未显式传 capabilities 时读全局注入档位', () async {
      PlatformCapabilities.debugOverride(const PlatformCapabilities.mobile());
      final _FakeWindowDriver driver = _FakeWindowDriver();

      final WindowGeometryController? controller =
          await configureWindowGeometry(
        _FakeSettingsRepository(stored: _geometry()),
        driver: driver,
      );

      expect(controller, isNull);
      expect(driver.totalCalls, 0);
    });
  });

  group('configureWindowGeometry 桌面行为', () {
    test('有合法记录：show 前套用尺寸与位置，并挂上监听', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final _FakeSettingsRepository settings = _FakeSettingsRepository(
        stored: _geometry(x: 240, y: 130, width: 1280, height: 860),
      );

      final WindowGeometryController? controller =
          await configureWindowGeometry(
        settings,
        driver: driver,
        capabilities: const PlatformCapabilities.desktop(apple: true),
      );

      expect(controller, isNotNull);
      expect(controller!.isAttached, isTrue);
      expect(driver.setSizeCalls, <Size>[const Size(1280, 860)]);
      expect(driver.setPositionCalls, <Offset>[const Offset(240, 130)]);
      expect(driver.listeners, hasLength(1));
      // 没有配置 onClose 时不拦截关窗。
      expect(driver.preventCloseCalls, isEmpty);

      await controller.detach();
      expect(driver.listeners, isEmpty);
    });

    test('配置了 onClose 时开启关窗拦截', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final WindowGeometryController? controller =
          await configureWindowGeometry(
        _FakeSettingsRepository(),
        driver: driver,
        capabilities: const PlatformCapabilities.desktop(),
        onClose: () async {},
      );

      expect(driver.preventCloseCalls, <bool>[true]);
      await controller!.detach();
      expect(driver.preventCloseCalls, <bool>[true, false]);
    });

    test('无记录：保持 WindowOptions 的默认尺寸（不调 setSize）', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final WindowGeometryController? controller =
          await configureWindowGeometry(
        _FakeSettingsRepository(),
        driver: driver,
        capabilities: const PlatformCapabilities.desktop(),
      );

      expect(controller, isNotNull);
      expect(driver.setSizeCalls, isEmpty);
      expect(driver.setPositionCalls, isEmpty);
      await controller!.detach();
    });

    test('记录非法（宽度小于最小值）时退回默认尺寸', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final WindowGeometryController? controller =
          await configureWindowGeometry(
        _FakeSettingsRepository(stored: _geometry(width: 320, height: 240)),
        driver: driver,
        capabilities: const PlatformCapabilities.desktop(),
      );

      expect(driver.setSizeCalls, isEmpty);
      await controller!.detach();
    });

    test('设置文件损坏（读取抛异常）时静默降级，不阻断启动', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final _FakeSettingsRepository settings = _FakeSettingsRepository(
        stored: _geometry(),
      )..throwOnLoad = true;

      final WindowGeometryController? controller =
          await configureWindowGeometry(
        settings,
        driver: driver,
        capabilities: const PlatformCapabilities.desktop(),
      );

      expect(controller, isNotNull);
      expect(driver.setSizeCalls, isEmpty);
      await controller!.detach();
    });
  });

  group('isRestorable 判据', () {
    test('正常几何可恢复', () {
      expect(WindowGeometryController.isRestorable(_geometry()), isTrue);
    });

    test('恰好等于最小尺寸可恢复', () {
      expect(AppConfig.desktopMinWidth, 360);
      expect(AppConfig.desktopMinHeight, 640);
      expect(
        WindowGeometryController.isRestorable(
          _geometry(
            width: AppConfig.desktopMinWidth,
            height: AppConfig.desktopMinHeight,
          ),
        ),
        isTrue,
      );
    });

    test('小于最小尺寸不可恢复', () {
      expect(
        WindowGeometryController.isRestorable(
          _geometry(width: AppConfig.desktopMinWidth - 1),
        ),
        isFalse,
      );
      expect(
        WindowGeometryController.isRestorable(
          _geometry(height: AppConfig.desktopMinHeight - 1),
        ),
        isFalse,
      );
    });

    test('超出上限（损坏记录）不可恢复', () {
      expect(
        WindowGeometryController.isRestorable(
          _geometry(width: AppConfig.desktopMaxRestoreExtent + 1),
        ),
        isFalse,
      );
    });

    test('NaN / Infinity 不可恢复', () {
      expect(
        WindowGeometryController.isRestorable(_geometry(x: double.nan)),
        isFalse,
      );
      expect(
        WindowGeometryController.isRestorable(_geometry(y: double.infinity)),
        isFalse,
      );
      expect(
        WindowGeometryController.isRestorable(_geometry(width: double.nan)),
        isFalse,
      );
      expect(
        WindowGeometryController.isRestorable(
          _geometry(height: double.negativeInfinity),
        ),
        isFalse,
      );
    });

    test('最小化时的 0 尺寸不可恢复', () {
      expect(
        WindowGeometryController.isRestorable(
          _geometry(width: 0, height: 0),
        ),
        isFalse,
      );
    });
  });

  group('save 回写', () {
    test('resize 后把当前几何写回设置', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver(
        size: const Size(1366, 768),
        position: const Offset(48, 24),
      );
      final _FakeSettingsRepository settings = _FakeSettingsRepository();
      final WindowGeometryController controller = WindowGeometryController(
        settings: settings,
        driver: driver,
      );

      await controller.save();

      expect(settings.saved, hasLength(1));
      expect(settings.saved.single.width, 1366);
      expect(settings.saved.single.height, 768);
      expect(settings.saved.single.x, 48);
      expect(settings.saved.single.y, 24);
    });

    test('最小化时读到 0 尺寸，不写脏数据', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver(size: Size.zero);
      final _FakeSettingsRepository settings = _FakeSettingsRepository();
      final WindowGeometryController controller = WindowGeometryController(
        settings: settings,
        driver: driver,
      );

      await controller.save();

      expect(settings.saved, isEmpty);
    });

    test('onWindowResized / onWindowMoved 会触发保存', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final _FakeSettingsRepository settings = _FakeSettingsRepository();
      final WindowGeometryController controller = WindowGeometryController(
        settings: settings,
        driver: driver,
      )
        ..onWindowResized()
        ..onWindowMoved();

      // 两个回调都是 unawaited，让出事件循环等它们跑完。
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(settings.saved, isNotEmpty);
      expect(controller.isAttached, isFalse);
    });
  });

  group('关窗链路（Windows 双重保险的窗口侧）', () {
    test('保存几何 → 执行收尾回调 → 销毁窗口', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final _FakeSettingsRepository settings = _FakeSettingsRepository();
      int onCloseCalls = 0;
      final WindowGeometryController controller = WindowGeometryController(
        settings: settings,
        driver: driver,
        onClose: () async => onCloseCalls++,
      );

      await controller.handleClose();

      expect(settings.saved, hasLength(1));
      expect(onCloseCalls, 1);
      expect(driver.destroyCalls, 1);
    });

    test('重复关窗只执行一次', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      int onCloseCalls = 0;
      final WindowGeometryController controller = WindowGeometryController(
        settings: _FakeSettingsRepository(),
        driver: driver,
        onClose: () async => onCloseCalls++,
      );

      await controller.handleClose();
      await controller.handleClose();

      expect(onCloseCalls, 1);
      expect(driver.destroyCalls, 1);
    });

    test('收尾回调抛异常时仍然销毁窗口（不能让 App 关不掉）', () async {
      final _FakeWindowDriver driver = _FakeWindowDriver();
      final WindowGeometryController controller = WindowGeometryController(
        settings: _FakeSettingsRepository(),
        driver: driver,
        onClose: () async => throw StateError('flush failed'),
      );

      await expectLater(controller.handleClose(), completes);
      expect(driver.destroyCalls, 1);
    });
  });

  group('WindowDragArea', () {
    testWidgets('非桌面直接返回 child，不引入拖动手势', (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: WindowDragArea(
            capabilities: PlatformCapabilities.mobile(),
            child: Text('title'),
          ),
        ),
      );

      expect(find.text('title'), findsOneWidget);
      expect(find.byType(DragToMoveArea), findsNothing);
    });

    testWidgets('macOS 左侧留出红绿灯内边距', (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: WindowDragArea(
            capabilities: PlatformCapabilities.desktop(apple: true),
            child: Text('title'),
          ),
        ),
      );

      final Padding padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(DragToMoveArea),
          matching: find.byType(Padding),
        ),
      );
      expect(
        padding.padding.resolve(TextDirection.ltr).left,
        AppConfig.macOSTrafficLightInset,
      );
    });

    testWidgets('Windows / Linux 不留内边距', (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: WindowDragArea(
            capabilities: PlatformCapabilities.desktop(),
            child: Text('title'),
          ),
        ),
      );

      final Padding padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(DragToMoveArea),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding.resolve(TextDirection.ltr).left, 0);
    });
  });
}
