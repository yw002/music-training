# interval_ear 全量验收报告（T25）

- **验收日期**：2026-08-10
- **批次范围**：E+ 批次 T22–T25
  - T22 响应式布局 / 键盘快捷键
  - T23 生命周期 / 桌面窗口管理
  - T24 打包脚本与工程配置
  - T25 全量验收（本报告）
- **验收人**：QA 工程师 严过关
- **代码状态**：T22–T24 改动位于工作树，**未提交**（`git status` 有 24 项 modified + 12 项 untracked）。本次验收针对工作树当前状态，**未执行任何 git commit / push**。
- **最终判定**：✅ **PASS（验收通过）** —— 已知限制均为环境性不可验项，非代码缺陷。

---

## 0. 验收口径说明

### 0.1 执行纪律（本次严格遵守）

| 纪律 | 说明 |
| --- | --- |
| 环境前置 | 所有 `flutter` 命令前均执行 `source tool/flutter_env.sh`（本机代理拦截 pub.dev，必须走 flutter-io.cn 镜像） |
| 测试隔离 | `flutter test` **逐目录 + `-j 1` 串行**执行，绝不整树一次性跑（整树并发会 OOM，进程被 SIGKILL / exit 137） |
| 分析范围 | `flutter analyze lib`（整项目 analyze 会因 iOS ephemeral 文件删除产生噪音，限定 `lib` 后结论干净） |
| 工具串行 | `flutter analyze` 与 `flutter test` **严格串行**，全程无并发（macOS 下并发会抢 startup lock 导致崩溃） |
| 输出真实性 | 本报告所有结论均粘贴真实命令输出，无任何推测或伪造 |

### 0.2 环境基线（按 T24 工程师提示更新）

**本机 Xcode 状态：已就绪，许可已接受。**

- `Xcode 26.6 (17F113)`，`xcode-select -p = /Applications/Xcode.app/Contents/Developer`
- `xcodebuild -version` 返回 0 —— **许可已接受**
- `tool/flutter_env.sh` 已不再覆盖 `DEVELOPER_DIR`，由完整版 Xcode 接管
- 工程为 Flutter 3.44+ 默认 **SwiftPM** 集成，仓库内无 `Podfile`，**不需要** `pod install`

> ⚠️ **口径更正**：真实的构建阻塞点是 **真机签名凭据缺失 / 无 Windows 主机 / 无 Android SDK**，
> **不是** Xcode 许可问题。构建脚本中「许可未接受 → exit 2」的分支属逻辑完备性保留，本机不会触发。

---

## A. 静态分析

### 执行命令

```bash
source tool/flutter_env.sh && flutter analyze lib
```

### 真实输出（结论行）

```
Analyzing lib...

36 issues found. (ran in 1.3s)
```

### 严重级别统计（真实计数）

```
error=0  warning=0  info=36
```

| 级别 | 数量 | 判定 |
| --- | :-: | --- |
| **error** | **0** | ✅ 满足验收标准（0 error） |
| **warning** | **0** | ✅ 满足 `analysis_options.yaml` 中「CI 要求 0 warning」 |
| info | 36 | ⚪ 可忽略（纯风格类 lint） |

### 关于退出码的诚实说明

`flutter analyze lib` 的真实退出码为 **1**，原因是 Flutter 在**存在任何 issue（含 info）**时即返回非 0，**并非**存在 error 或 warning。已通过逐级 grep 计数交叉验证：`error=0  warning=0  info=36`。

**按验收标准（0 error，info 可忽略）→ A 项判定 PASS。**

### 36 条 info 的分布（全为风格建议，不影响功能）

| lint 规则 | 条数 | 说明 |
| --- | :-: | --- |
| `prefer_const_constructors` | 11 | 建议加 `const` |
| `prefer_initializing_formals` | 11 | 建议用初始化形参 |
| `prefer_const_declarations` | 7 | 建议 `final` → `const` |
| `directives_ordering` | 2 | import 分区排序 |
| `unnecessary_underscores` | 1 | `__` → `_` |
| 其他 | 4 | — |

> 建议（非阻塞）：可在后续清理批次统一 `dart fix --apply` 消除。

---

## B. 全量测试（逐目录 `-j 1` 串行）

### 测试目录清单确认

全仓共 **68** 个 `*_test.dart` 文件，分布于 4 个顶层目录。已确认 **`test/` 根目录下无任何散落的 `.dart` 测试文件**（仅有 `.DS_Store`），因此无需额外单独执行根文件。

3 个非测试辅助文件（`test_support.dart` / `painter_golden_helpers.dart` / `test_data.dart`）为 helper，不含 `main()`，不单独计入。

### 执行命令（严格逐目录、串行、`-j 1`）

```bash
source tool/flutter_env.sh
flutter test test/app      -j 1
flutter test test/core     -j 1
flutter test test/audio    -j 1
flutter test test/features -j 1
```

### 逐目录明细表

| 测试目录 | 测试文件数 | passed | failed | 退出码 | 判定 |
| --- | :-: | :-: | :-: | :-: | :-: |
| `test/app` | 6 | **106** | **0** | 0 | ✅ |
| `test/core` | 17 | **180** | **0** | 0 | ✅ |
| `test/audio` | 12 | **79** | **0** | 0 | ✅ |
| `test/features` | 33 | **168** | **0** | 0 | ✅ |
| **总计** | **68** | **533** | **0** | — | ✅ **全绿** |

### 各目录真实输出（末行汇总）

**`test/app`** — exit 0
```
00:03 +105: .../test/app/router/transitions_test.dart: ContainerTransformPageRoute（M-01 首页 → 训练） off 档：一帧到位
00:03 +106: All tests passed!
```

**`test/core`** — exit 0
```
00:06 +179: .../test/core/widgets/widgets_test.dart: WarningBanner triggers onAction
00:06 +180: All tests passed!
```

**`test/audio`** — exit 0
```
00:04 +78: .../test/audio/audio_timeline_test.dart: AudioTimeline tailPadding 总时长 = PCM 样本数 + 尾部 80ms padding（含 padding 但不进 WAV）
00:04 +79: All tests passed!
```

**`test/features`** — exit 0
```
00:19 +167: .../test/features/free_training/presentation/widgets/free_training_page_test.dart: 点击开始训练会持久化配置
00:19 +168: All tests passed!
```

### 失败用例分析

**无。** 四个目录 `[E]`（错误标记）计数均为 **0**，无 `-N` 失败计数行出现。

**B 项判定：PASS（533 passed / 0 failed）。未发现任何源码 Bug，无需回退工程师修复。**

---

## C. 防泄露专项复查（架构硬约束）

> 判定口径：**注释中的说明文字不算违规**，仅 `import` 语句与真实键值（`<key>` 元素）算违规。

### 汇总

| # | 检查项 | 判定 |
| :-: | --- | :-: |
| C1 | `fl_chart` 禁止引入 | ✅ PASS |
| C2 | `google_fonts` 禁止引入 | ✅ PASS |
| C3 | 裸 `Platform.isX` 收敛 | ✅ PASS（附命中清单与 2 项技术债建议） |
| C4 | macOS Release entitlements 无网络/设备权限 | ✅ PASS |
| C5 | iOS Info.plist 无隐私权限键 | ✅ PASS |
| C6 | `window_manager` / `SystemChrome` 不越界 | ✅ PASS |

---

### C1. `fl_chart` 禁止引入 —— ✅ PASS

```bash
grep -rn "fl_chart" lib/
```

唯一命中：

```
lib/features/report/presentation/report_page.dart:30:/// CustomPainter（架构 §7.3 禁止 fl_chart）。分区按 M-24 交错入场（360/120）。
```

**判定 PASS**：唯一命中位于 `///` 文档注释，是**约束声明本身**，非 import。交叉核对 `pubspec.yaml`：

```
PASS: pubspec.yaml 未声明 fl_chart / google_fonts
```

图表全部由 `CustomPainter` 实现（`bar_chart_painter` / `line_chart_painter` / `matrix_painter` / `heatmap_painter` / `ring_painter`，均有对应测试且全绿）。

---

### C2. `google_fonts` 禁止引入 —— ✅ PASS

```bash
grep -rn "google_fonts\|GoogleFonts" lib/
```

唯一命中：

```
lib/app/theme/typography.dart:5:/// **策略 B（PRD §0.3 决议）**：不内置 Inter 字体文件、不引 `google_fonts`，
```

**判定 PASS**：唯一命中位于文档注释，是**策略声明本身**，非 import。`pubspec.yaml` 亦未声明该依赖。UI/测试仅用系统字体。

---

### C3. 裸 `Platform.isX` 收敛检查 —— ✅ PASS（含技术债建议）

```bash
grep -rnE "Platform\.(isIOS|isAndroid|isMacOS|isWindows|isLinux)" lib/
```

**完整命中清单（6 处 / 4 个文件）**：

| # | 位置 | 代码 | 判定 |
| :-: | --- | --- | --- |
| 1 | `lib/core/platform/platform_capabilities.dart:84` | `isMobile: Platform.isAndroid \|\| Platform.isIOS` | ✅ 授权位置 |
| 2 | `lib/core/platform/platform_capabilities.dart:85` | `isDesktop: Platform.isWindows \|\| Platform.isMacOS \|\| Platform.isLinux` | ✅ 授权位置 |
| 3 | `lib/core/platform/platform_capabilities.dart:87` | `isApple: Platform.isMacOS \|\| Platform.isIOS` | ✅ 授权位置 |
| 4 | `lib/core/storage/app_paths.dart:45` | `if (Platform.isAndroid \|\| Platform.isIOS)` | ✅ 合理位置 |
| 5 | `lib/features/settings/presentation/platform_support.dart:13` | `return Platform.isAndroid \|\| Platform.isIOS` | ⚠️ 已封装，建议收敛 |
| 6 | `lib/features/settings/presentation/widgets/data_management_section.dart:32` | `return Platform.isWindows \|\| Platform.isMacOS \|\| Platform.isLinux` | ⚠️ 建议收敛 |

**逐项判定理由**：

- **#1–#3（`PlatformCapabilities._detect()`）**：这正是架构指定的**唯一平台探测收敛点**，且 `kIsWeb` 已前置守卫。**完全合规**。
- **#4（`app_paths.dart`）**：基础设施层沙盒根目录解析（Documents vs ApplicationSupport），在 early-boot 阶段执行，不宜反向依赖上层能力抽象。**合理位置，判定通过**。
- **#5（`platform_support.dart`）**：位于 presentation 层，但该文件本身就是**集中封装**（文件注释即写明「集中封装平台判断，避免页面裸写 `Platform.isX`」），页面侧未裸写。属 T17 时期既有封装，与 `PlatformCapabilities.hasHaptics` **功能重复**。
- **#6（`data_management_section.dart`）**：唯一一处**页面 widget 内直接书写** `Platform.isX`（私有 getter `_isDesktop`）。有 `kIsWeb` 守卫，测试全绿、不引发崩溃。

**C3 综合判定：PASS。** 无阻塞性违规——所有平台探测要么在授权抽象内，要么有 `kIsWeb` 守卫且已局部封装。

> 📌 **技术债建议（非阻塞，不影响本次验收结论）**
> #5 与 #6 均为 **T22–T24 之前的既有代码**（`git status` 显示两文件本批次未被修改），建议后续清理批次统一改走 `PlatformCapabilities.instance.hasHaptics` / `.isDesktop`，删除 `platform_support.dart` 这一重复抽象，使平台探测真正单点收敛。

---

### C4. macOS Release entitlements —— ✅ PASS

文件：`macos/Runner/Release.entitlements`

**真实 `<key>` 元素全清单**：

```
<key>com.apple.security.app-sandbox</key>
<key>com.apple.security.files.user-selected.read-write</key>
```

**禁项核查**：

```
PASS: 4 项禁项均未作为真实 key 出现（仅存在于注释说明）
```

| 禁项 | 是否作为真实 key 出现 |
| --- | :-: |
| `com.apple.security.network.client` | ❌ 缺席 ✅ |
| `com.apple.security.network.server` | ❌ 缺席 ✅ |
| `com.apple.security.device.audio-input` | ❌ 缺席 ✅ |
| `com.apple.security.device.camera` | ❌ 缺席 ✅ |

> 说明：朴素 grep 会在 8–11 行命中这四个字符串，但它们全部位于 `<!-- T24 §9.2.3 安全审计基线 -->` **注释块**内，是约束声明文本，非生效键值。已用「仅提取 `<key>` 元素」的严格 grep 交叉证伪。

**对照组 `DebugProfile.entitlements`**（真实 key）：

```
<key>com.apple.security.app-sandbox</key>
<key>com.apple.security.cs.allow-jit</key>
<key>com.apple.security.network.server</key>
<key>com.apple.security.files.user-selected.read-write</key>
```

Debug 保留 `cs.allow-jit` + `network.server` 属 Flutter 模板热重载 VM Service 所需，**仅 Debug/Profile 生效，Release 已彻底清除**，符合 T24 设计。

---

### C5. iOS 隐私权限键 —— ✅ PASS

文件：`ios/Runner/Info.plist`

**禁项核查**：

```
PASS: 4 项隐私键均未作为真实 key 出现（仅存在于注释说明）
```

| 禁项 | 是否作为真实 key 出现 |
| --- | :-: |
| `NSMicrophoneUsageDescription` | ❌ 缺席 ✅ |
| `NSCameraUsageDescription` | ❌ 缺席 ✅ |
| `NSPhotoLibraryUsageDescription` | ❌ 缺席 ✅ |
| `UIBackgroundModes` | ❌ 缺席 ✅ |

**Info.plist 真实 `<key>` 全清单（27 项，均为标准 Bundle/Scene/UI 配置）**：

```
CADisableMinimumFrameDurationOnPhone, CFBundleDevelopmentRegion, CFBundleDisplayName,
CFBundleExecutable, CFBundleIdentifier, CFBundleInfoDictionaryVersion, CFBundleName,
CFBundlePackageType, CFBundleShortVersionString, CFBundleSignature, CFBundleVersion,
LSRequiresIPhoneOS, UIApplicationSceneManifest, UIApplicationSupportsMultipleScenes,
UISceneConfigurations, UIWindowSceneSessionRoleApplication, UISceneClassName,
UISceneConfigurationName, UISceneDelegateClassName, UISceneStoryboardFile,
UIApplicationSupportsIndirectInputEvents, UILaunchStoryboardName, UIMainStoryboardFile,
UIStatusBarStyle, UISupportedInterfaceOrientations, UISupportedInterfaceOrientations~ipad,
UIViewControllerBasedStatusBarAppearance
```

**无任何 `NS*UsageDescription` 键**，符合「不录音 / 不拍照 / 不后台播放」的产品约束。第 83–86 行的字符串命中同样位于注释块，为「刻意缺席」的说明文本。

---

### C6. `window_manager` / `SystemChrome` 越界检查 —— ✅ PASS

**`window_manager` 命中分布（按文件归并）**：

| 文件 | 性质 | 判定 |
| --- | --- | :-: |
| `lib/core/platform/window_setup.dart` | 真实 import + `WindowManagerDriver` 实现（唯一驱动封装点） | ✅ 授权 |
| `lib/app/app_bootstrap.dart` | 真实 import + `ensureInitialized` / `waitUntilReadyToShow` / `show` / `focus`（启动路径） | ✅ 授权 |
| `lib/app/app_lifecycle_handler.dart:63` | 仅注释提及 | ✅ 不违规 |
| `lib/core/platform/system_chrome_setup.dart:44` | 仅注释提及 | ✅ 不违规 |

**`SystemChrome` 命中分布**：

| 文件 | 性质 | 判定 |
| --- | --- | :-: |
| `lib/core/platform/system_chrome_setup.dart` | `PlatformSystemChromeDriver` 内调用 `setEnabledSystemUIMode` / `setSystemUIOverlayStyle` | ✅ 授权 |
| `lib/app/app_bootstrap.dart:61` | `await SystemChromeSetup.configure()`（启动路径，经抽象层） | ✅ 授权 |

**判定 PASS**：两者**均未出现在任何页面 widget**（`features/**/pages/`、`features/**/widgets/` 零命中）。

架构上二者都做了 **Driver 接口抽象**（`WindowDriver` / `SystemChromeDriver`），测试可注入内存替身而不打平台通道 —— 这正是 `test/core/platform/window_setup_test.dart` 与 `system_chrome_setup_test.dart` 能在无平台通道环境下全绿的原因。`window_setup.dart:296` 还额外声明了「非桌面端直接返回 `null`，不触碰任何 `window_manager` API」的守卫。

> 说明：`window_setup.dart` / `system_chrome_setup.dart` 物理位置在 `lib/core/platform/` 而非 `lib/app/`，这是 T22/T23 既定的分层归属（core 提供能力抽象，app 负责启动编排），**符合架构设计，不构成越界**。

---

## D. 已知限制（本机不可验证项）

以下项目**不属于 T25 验收范围**，其不可验证原因为**环境性**（缺硬件 / 缺凭据 / 缺 SDK），**非代码缺陷**。引用 T24 `README.md`「本机验证状态（诚实声明）」章节：

| # | 项目 | 状态 | 阻塞原因 | 需在何处执行 |
| :-: | --- | :-: | --- | --- |
| 1 | macOS Release 真机构建 | `unverified` | 签名/公证需 **Developer ID 证书** 与 Apple ID 凭据；本机仅有 Apple Development 证书 | `./tool/build_macos.sh` |
| 2 | iOS 真机构建 / ipa 导出 | `unverified` | 需**真机签名**（Team ID + 描述文件 + 已注册设备）；`ios/ExportOptions.plist` 的 `teamID` 仍为占位值 `REPLACE_WITH_TEAM_ID` | `TEAM_ID=<团队ID> ./tool/build_ios.sh` |
| 3 | Windows Release 构建 | `unverified` | **本机为 macOS，无 Windows 主机**；且需 VS 2022「使用 C++ 的桌面开发」工作负载 | Windows 上 `powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1` |
| 4 | Android Release 构建 | `unverified` | 本机 `ANDROID_HOME` / `ANDROID_SDK_ROOT` **均未设置**，无可用 Android SDK | 装 SDK 后 `./tool/build_android.sh` |
| 5 | macOS 沙盒 entitlements 实际生效性 | `unverified` | 需在**已签名的沙盒 Release 包**中验证导出/导入对话框可用（静态文本已验，见 C4） | 签名构建后手动验证 |
| 6 | iOS 音频会话类别（静音开关下是否发声） | `unverified` | 必须**真机**验证，模拟器行为不等价 | 真机运行后手动确认 |

### ⚠️ 口径更正（重要）

上述 6 项的阻塞原因中，**没有一项是「Xcode 许可未接受」**。

本机实测 `Xcode 26.6 (17F113)` 已完整安装、`xcodebuild -version` 返回 0、许可已接受。构建脚本中「许可未接受 → `exit 2`」的分支为**逻辑完备性保留**，本机不会触发，因此**未经实际触发验证**。

真实阻塞点归纳为三类：**① 真机签名凭据缺失（#1 #2 #5 #6）、② 无 Windows 主机（#3）、③ 无 Android SDK（#4）**。

---

## E. 最终判定

# ✅ PASS —— 验收通过

| 验收项 | 结论 | 数据 |
| --- | :-: | --- |
| **A. 静态分析** | ✅ PASS | `flutter analyze lib` → **0 error / 0 warning / 36 info** |
| **B. 全量测试** | ✅ PASS | 4 目录逐一 `-j 1` 串行，**533 passed / 0 failed**，全部 `All tests passed!` |
| **C. 防泄露专项** | ✅ PASS | 6 项全部通过，无阻塞性违规 |
| **D. 已知限制** | ⚪ 环境性 | 6 项 `unverified`，均因缺硬件/凭据/SDK，**非代码缺陷**，不在 T25 范围 |

### 判定说明

1. **零源码 Bug**：本轮 533 个用例全绿，`[E]` 错误标记计数为 0，**未发现需回退工程师修复的源码缺陷**。
2. **零测试 Bug**：无需 QA 自行修复任何测试代码，**Round 1 一轮即通过**，未进入 Round 2。
3. **架构硬约束零泄露**：`fl_chart` / `google_fonts` 零 import；网络与设备权限在 Release 侧彻底缺席；`window_manager` / `SystemChrome` 严格锁定在抽象层与启动路径。
4. **非阻塞技术债 2 项**（已在 C3 记录）：`platform_support.dart` 与 `data_management_section.dart` 中的裸 `Platform.isX`，均为本批次之前的既有代码，建议后续统一收敛至 `PlatformCapabilities`。
5. **代码未提交**：遵守用户铁律，本次验收**未执行任何 `git commit` / `git push`**，改动保留在工作树等待用户授权。

---

## 附录：本次验收执行的完整命令序列

```bash
# A. 静态分析（与测试严格串行）
source tool/flutter_env.sh && flutter analyze lib

# B. 全量测试（逐目录、-j 1、串行）
source tool/flutter_env.sh && flutter test test/app      -j 1
source tool/flutter_env.sh && flutter test test/core     -j 1
source tool/flutter_env.sh && flutter test test/audio    -j 1
source tool/flutter_env.sh && flutter test test/features -j 1

# C. 防泄露专项
grep -rn  "fl_chart" lib/
grep -rn  "google_fonts\|GoogleFonts" lib/
grep -rnE "Platform\.(isIOS|isAndroid|isMacOS|isWindows|isLinux)" lib/
grep -oE  "<key>[^<]+</key>" macos/Runner/Release.entitlements
grep -oE  "<key>[^<]+</key>" ios/Runner/Info.plist
grep -rn  "window_manager\|windowManager\|WindowManager" lib/
grep -rn  "SystemChrome" lib/
```

---

*报告生成：2026-08-10 · QA 工程师 严过关 · 批次 E+ T25 全量验收*
