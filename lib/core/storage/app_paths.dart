import 'dart:io';

import 'package:interval_ear/core/constants/app_config.dart';
import 'package:path_provider/path_provider.dart';

/// 应用数据目录解析（T15 验收 5）。
///
/// 四端各自映射到正确的沙盒位置：Android/iOS 用 `Documents`，桌面端用
/// `ApplicationSupport`（符合各平台规范，§0.2）。所有存储路径统一经本文件出口，
/// 业务层永远不直接拼路径。
abstract final class AppPaths {
  const AppPaths._();

  /// 应用数据子目录名（[AppConfig.dataDirName]）。
  static const String _dataDirName = AppConfig.dataDirName;

  /// 解析数据根目录，必要时递归创建。
  static Future<Directory> dataDir() async {
    final base = await _appDataBase();
    final dir = Directory('${base.path}/$_dataDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 数据目录下某个文件的句柄（自动创建父目录）。
  static Future<File> file(String name) async {
    final dir = await dataDir();
    return File('${dir.path}/$name');
  }

  /// 数据目录下的某个子目录（自动创建）。
  static Future<Directory> subDir(String name) async {
    final dir = await dataDir();
    final sub = Directory('${dir.path}/$name');
    if (!await sub.exists()) {
      await sub.create(recursive: true);
    }
    return sub;
  }

  /// 平台相关的沙盒根目录。
  static Future<Directory> _appDataBase() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return getApplicationDocumentsDirectory();
    }
    // Windows / macOS / Linux / 其它：应用专属支持目录。
    return getApplicationSupportDirectory();
  }
}
