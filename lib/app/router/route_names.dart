/// 全部路由常量（架构 §1.6 路由表）。
///
/// 页面只有 9 个、无深链接、无 URL、无嵌套 shell 路由需求，因此使用
/// Navigator 1.0 + 集中式 `AppRouter.onGenerateRoute`，不引 `go_router`。
abstract final class RouteNames {
  /// 首页 `/`。
  static const String home = '/';

  /// 训练页 `/training`（多选模式）。
  static const String training = '/training';

  /// 二选一训练页 `/training/binary`。
  static const String binaryTraining = '/training/binary';

  /// 本组小结 `/summary`。
  static const String sessionSummary = '/summary';

  /// 自由训练配置 `/free`。
  static const String freeTraining = '/free';

  /// 训练报告 `/report`。
  static const String report = '/report';

  /// 设置 `/settings`。
  static const String settings = '/settings';

  /// 关于 `/about`。
  static const String about = '/about';

  /// 薄弱音程全部列表 `/weak`。
  static const String weakPairs = '/weak';

  /// 全部路由名，按路由表顺序。用于单测覆盖检查。
  static const List<String> all = <String>[
    home,
    training,
    binaryTraining,
    sessionSummary,
    freeTraining,
    report,
    settings,
    about,
    weakPairs,
  ];

  /// 是否为已登记的路由。
  static bool isKnown(String? name) => name != null && all.contains(name);
}
