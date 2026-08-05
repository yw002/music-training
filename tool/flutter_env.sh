#!/usr/bin/env bash
# 本机 Flutter 环境变量（必须 source 后再执行任何 flutter/dart 命令）
#
# 背景：本机代理拦截了 pub.dev（CONNECT tunnel 502），直连会导致 flutter 命令
# 无限期挂起。必须走 flutter-io.cn 镜像。
#
# 关于 Xcode（2026-08-04 更新）：
#   - 用户已执行 `sudo xcodebuild -license accept`（Xcode 26.6 完整版已就绪）。
#   - 因此不再需要把 DEVELOPER_DIR 指向 CommandLineTools 来绕开许可探测。
#   - Flutter 3.44+ 默认使用 SwiftPM（苹果官方包管理器），不再默认依赖 CocoaPods。
#     打包脚本与 Podfile 相关步骤请改用 SwiftPM，不要安装/执行 pod。
#
# 用法：
#   source tool/flutter_env.sh && flutter pub get

export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
# 注意：不再覆盖 DEVELOPER_DIR，让 Xcode 26.6 完整版接管（许可已接受）。
