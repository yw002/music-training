/// 资源路径常量。
///
/// 集中声明的目的：`pubspec.yaml` 的 `assets:` / `fonts:` 段与代码里的字符串
/// 必须保持一致，散落在各处时改一个漏一个是最常见的运行时崩溃来源。
abstract final class AssetPaths {
  const AssetPaths._();

  /// 字体目录。
  static const String fontsDir = 'assets/fonts';

  /// Inter Regular（架构 §0.3 方案 A，待用户提供后启用）。
  static const String interRegular = '$fontsDir/Inter-Regular.ttf';

  /// Inter Medium。
  static const String interMedium = '$fontsDir/Inter-Medium.ttf';

  /// Inter SemiBold。
  static const String interSemiBold = '$fontsDir/Inter-SemiBold.ttf';

  /// Inter Bold。
  static const String interBold = '$fontsDir/Inter-Bold.ttf';

  /// 全部 Inter 字重文件，供「启用内置字体前的存在性自检」使用。
  static const List<String> interFontFiles = <String>[
    interRegular,
    interMedium,
    interSemiBold,
    interBold,
  ];

  /// 图标目录（本项目图标全部用 Material Icons，此目录预留给品牌图形）。
  static const String iconsDir = 'assets/icons';

  /// 应用图标（桌面窗口标题栏用）。
  static const String appIcon = '$iconsDir/app_icon.png';
}
