# interval_ear · 音程听辨训练

一款离线的音程听辨训练 App（Flutter，覆盖 macOS / iOS / Android / Windows）。
音频由 `flutter_soloud` **本地实时合成**，**不联网、不录音、不申请任何隐私权限**。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## 开发环境

本机网络代理会拦截 pub.dev，**执行任何 `flutter` / `dart` 命令前必须先 source 环境脚本**：

```bash
cd /path/to/music-training
source tool/flutter_env.sh
flutter pub get
```

`tool/flutter_env.sh` 负责设置 `PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL` 镜像源。
所有 `tool/*.sh` 构建脚本内部都会自动 source 它，直接运行脚本即可，无需手动 source。

> 依赖管理：本工程为 Flutter 3.44+ 默认的 **SwiftPM** 集成，
> 仓库内 **没有** `ios/Podfile` / `macos/Podfile`，也**不需要**执行 `pod install`。

---

## 构建与打包

### 脚本清单（`tool/`）

| 脚本 | 用途 | 执行宿主 |
| --- | --- | --- |
| `tool/build_macos.sh` | macOS Release 构建（可选公证） | macOS |
| `tool/build_ios.sh` | iOS Release 构建（无签名 / 签名 ipa 导出） | macOS |
| `tool/build_android.sh` | Android Release APK / AAB 构建 | macOS / Linux / Windows(WSL) |
| `tool/build_windows.ps1` | Windows Release 构建 | **Windows** |
| `tool/verify_all.sh` | 总验证：analyze → test（逐目录 `-j 1`）→ 四端构建，失败继续并汇总 | macOS / Linux |

### 用法

```bash
# 一次性跑完全部验证（每步失败如实记录并继续，最后打印汇总）
./tool/verify_all.sh

# 单端构建
./tool/build_macos.sh
./tool/build_ios.sh                    # 未设置 TEAM_ID → --no-codesign 无签名构建
TEAM_ID=A1B2C3D4E5 ./tool/build_ios.sh # 设置 TEAM_ID → 走 ios/ExportOptions.plist 导出 ipa
./tool/build_android.sh                        # 默认 apk
ANDROID_BUILD_TARGET=appbundle ./tool/build_android.sh
```

Windows 主机：

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
```

### 退出码约定（所有构建脚本统一）

| 退出码 | 含义 |
| :-: | --- |
| `0` | 构建成功，且**产物已实测存在**（命令返回 0 但产物缺失同样判失败） |
| `1` | 构建失败（子命令返回非 0 / 产物缺失） |
| `2` | **工具链缺失**，未执行（非代码问题）。例如 Xcode 许可未接受、无 Android SDK、无 Visual Studio C++ 工作负载 |

`verify_all.sh` 依此把每一步归为 `✅ PASS` / `⚠️ SKIPPED`（退出码 2）/ `❌ FAIL`，
整体退出码：有 `❌` → `1`，否则 `0`（`⚠️` 会在汇总里明确标注**未经验证**）。

### 签名凭据

复制模板后填入真实值，该文件**不入库**（已在 `.gitignore`）：

```bash
cp tool/signing.env.example tool/signing.env
```

| 变量 | 用途 | 未设置时的行为 |
| --- | --- | --- |
| `TEAM_ID` | Apple 开发者团队 ID | iOS 走 `--no-codesign` |
| `CODESIGN_IDENTITY` | macOS 签名证书名 | 走 Xcode 默认 / 本地临时签名 |
| `NOTARIZE_PROFILE` | `notarytool` keychain profile 名 | 跳过公证 |

`ios/ExportOptions.plist` 中的 `teamID` 目前为占位值 `REPLACE_WITH_TEAM_ID`，
导出 ipa 前必须替换为真实团队 ID。

---

## 本机验证状态（诚实声明）

> 本节严格区分「**已在本机实际执行并通过**」与「**本机未执行 / 不可验证**」。
> 未执行的步骤一律不声称成功——请勿把「脚本已写好」理解为「构建已验证」。

### ✅ 已在 macOS 宿主实际执行并通过

| 项目 | 命令 |
| --- | --- |
| 静态分析 | `flutter analyze lib` → **0 error** |
| 单元测试 | `flutter test`（逐目录 `-j 1`） |
| 脚本语法检查 | `bash -n tool/build_macos.sh tool/build_ios.sh tool/build_android.sh tool/verify_all.sh` |
| plist 格式校验 | `plutil -lint` 校验全部 macOS/iOS plist |

### ❌ 本机未执行 / 不可验证（需开发者在对应环境自行执行）

| 项目 | 原因 | 需自行执行 |
| --- | --- | --- |
| macOS Release 真机构建 | 未在本机执行完整构建；产物签名/公证需 Developer ID 证书与 Apple ID 凭据（本机仅有 Apple Development 证书） | `./tool/build_macos.sh` |
| iOS 真机构建 / ipa 导出 | 需真机签名（Team ID + 描述文件 + 已注册设备），`ExportOptions.plist` 的 `teamID` 仍是占位值 | `TEAM_ID=<你的团队ID> ./tool/build_ios.sh` |
| iOS 音频会话类别（静音开关下是否发声） | 必须真机验证，模拟器行为不等价 | 真机运行后手动确认 |
| Windows Release 构建 | **本机为 macOS，无 Windows 主机**，且需 Visual Studio 2022「使用 C++ 的桌面开发」工作负载 | 在 Windows 上 `powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1` |
| Android Release 构建 | 本机 `ANDROID_HOME` / `ANDROID_SDK_ROOT` **均未设置**，无可用 Android SDK | 安装 SDK 并 `export ANDROID_HOME=...` 后 `./tool/build_android.sh` |
| macOS 沙盒 entitlements 实际生效性 | 需在已签名的沙盒 Release 包中验证导出/导入对话框可用 | 签名构建后手动验证 |

> 本机 Xcode 状态（实测）：`Xcode 26.6 (17F113)`，`xcode-select -p = /Applications/Xcode.app/Contents/Developer`，
> `xcodebuild -version` 返回 0（**许可已接受**）。
> 因此构建脚本中的「许可未接受 → `exit 2` 提示 `sudo xcodebuild -license accept`」分支
> 在本机不会触发；该分支为**逻辑完备性保留**，未在本机实际触发验证。

---

## 工程配置要点（T24）

- **macOS entitlements**（`macos/Runner/{DebugProfile,Release}.entitlements`）
  - Release 中**绝不出现** `network.client` / `network.server` / `device.audio-input` / `device.camera`
    —— 这是「不依赖网络、不录音」的技术兑现。
  - `com.apple.security.files.user-selected.read-write`：数据导出/导入（`file_selector`）在沙盒下必需。
  - DebugProfile 额外保留 Flutter 模板自带的 `cs.allow-jit` + `network.server`（热重载 VM Service 所需，仅 Debug/Profile）。
- **权限键一律不声明**：`NSMicrophoneUsageDescription`、`NSCameraUsageDescription`、
  `NSPhotoLibrary*UsageDescription`、`UIBackgroundModes: audio` 全部**刻意缺席**，请勿因插件文档提示而添加。
- **最低系统版本**：macOS `10.15`、iOS `13.0`（真相源在 `*.xcodeproj/project.pbxproj`，plist 通过变量引用 / 由 Xcode 注入）。
