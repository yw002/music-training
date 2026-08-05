import 'package:interval_ear/app/app_bootstrap.dart';

/// 应用入口。
///
/// 这里只做一件事：把控制权交给 [AppBootstrap]。所有初始化逻辑都放在
/// `app_bootstrap.dart`，这样集成测试可以直接调用 `AppBootstrap.run()`
/// 而不必依赖 `main()`。
Future<void> main() => AppBootstrap.run();
