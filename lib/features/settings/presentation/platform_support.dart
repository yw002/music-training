import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 是否支持触觉反馈（移动端有振动马达）。
///
/// 桌面端没有振动反馈能力，设置页据此隐藏「触觉反馈」开关（验收 ⑤）。
/// 集中封装平台判断，避免页面裸写 `Platform.isX`。
bool get supportsHapticFeedback {
  if (kIsWeb) {
    return false;
  }
  return Platform.isAndroid || Platform.isIOS;
}
