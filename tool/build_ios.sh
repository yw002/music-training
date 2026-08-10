#!/usr/bin/env bash
# =============================================================================
# tool/build_ios.sh —— iOS Release 构建脚本（批次 E+ · T24）
#
# 设计铁律（架构 §9.4.2 / §8 风险点 2）：
#   1. 第一步 source tool/flutter_env.sh。
#   2. 工具链前置检查（xcodebuild + 许可；仅当仓库存在 Podfile 时才要求 pod）。
#   3. 严禁伪造成功：只有构建返回 0 **且** 产物真实存在才打印「构建成功」。
#
# 依赖管理说明：本工程为 Flutter 3.44+ 默认的 **SwiftPM** 集成，
#   仓库内 **没有** ios/Podfile（见 tool/flutter_env.sh 注释）。
#   因此本脚本不会主动执行 pod install；仅在检测到 Podfile 时才要求 pod 可用。
#
# 退出码约定：
#   0 = 构建成功（产物已落盘并校验存在）
#   1 = 构建失败
#   2 = 工具链缺失 / Xcode 许可未接受
#
# 可选环境变量（见 tool/signing.env.example）：
#   TEAM_ID  Apple 开发者团队 ID；未设置 → 走 --no-codesign 无签名构建
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=tool/flutter_env.sh
source "${SCRIPT_DIR}/flutter_env.sh"

cd "${PROJECT_ROOT}"

readonly EXIT_BUILD_FAILED=1
readonly EXIT_TOOLCHAIN_MISSING=2
readonly EXPORT_OPTIONS_PLIST="ios/ExportOptions.plist"

if [[ -f "${SCRIPT_DIR}/signing.env" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/signing.env"
fi

TEAM_ID="${TEAM_ID:-}"

echo "════════ iOS Release 构建 ════════"
echo "项目根目录：${PROJECT_ROOT}"

# ── 1. 工具链前置检查：flutter ─────────────────────────────────────────────
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ 工具链缺失：找不到命令 'flutter'。"
  echo "   请确认 Flutter SDK 已安装且在 PATH 中。"
  exit "${EXIT_TOOLCHAIN_MISSING}"
fi

# ── 2. 工具链前置检查：xcodebuild + Xcode 许可 ─────────────────────────────
xcodebuild_output=""
xcodebuild_ok=1
if ! xcodebuild_output="$(xcodebuild -version 2>&1)"; then
  xcodebuild_ok=0
fi

if [[ "${xcodebuild_ok}" -ne 1 ]] \
   || printf '%s' "${xcodebuild_output}" | grep -qi 'license'; then
  echo "❌ 无法构建 iOS：xcodebuild 不可用或 Xcode 许可未接受。"
  echo "   xcodebuild 输出："
  printf '     %s\n' "${xcodebuild_output:-<无输出>}"
  echo "   当前 DEVELOPER_DIR = ${DEVELOPER_DIR:-<未设置，使用 xcode-select 默认值>}"
  echo "   请先执行: sudo xcodebuild -license accept"
  echo "   若指向 CommandLineTools，另需: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit "${EXIT_TOOLCHAIN_MISSING}"
fi

echo "✔ xcodebuild 可用："
printf '    %s\n' "${xcodebuild_output}"

# ── 3. CocoaPods：仅在存在 Podfile 时才是硬依赖 ────────────────────────────
if [[ -f "ios/Podfile" ]]; then
  if ! command -v pod >/dev/null 2>&1; then
    echo "❌ 工具链缺失：检测到 ios/Podfile，但找不到命令 'pod'。"
    echo "   请执行: sudo gem install cocoapods   （或 brew install cocoapods）"
    exit "${EXIT_TOOLCHAIN_MISSING}"
  fi
  echo "✔ 检测到 ios/Podfile，CocoaPods 可用：$(pod --version 2>/dev/null || echo '未知版本')"
else
  echo "ℹ️  未检测到 ios/Podfile —— 本工程走 Flutter 3.44+ 的 SwiftPM 集成，无需 CocoaPods。"
fi

# ── 4. 依赖拉取 ───────────────────────────────────────────────────────────
echo "──────── flutter pub get ────────"
if ! flutter pub get; then
  echo "❌ flutter pub get 失败（依赖未就绪，终止构建）。"
  exit "${EXIT_BUILD_FAILED}"
fi

# ── 5. 构建：有 TEAM_ID 走 ipa 导出，否则走无签名构建 ──────────────────────
if [[ -z "${TEAM_ID}" ]]; then
  echo "ℹ️  未设置 TEAM_ID，执行无签名构建（产物不可安装到真机）。"
  echo "──────── flutter build ios --release --no-codesign ────────"
  if ! flutter build ios --release --no-codesign; then
    echo "❌ iOS 无签名构建失败（flutter build ios --release --no-codesign 返回非 0）。"
    exit "${EXIT_BUILD_FAILED}"
  fi

  ARTIFACT="build/ios/iphoneos/Runner.app"
  if [[ ! -d "${ARTIFACT}" ]]; then
    echo "❌ 构建命令返回 0，但未找到产物 ${ARTIFACT}。"
    echo "   按「禁伪造成功」铁律，此处判定为构建失败。"
    exit "${EXIT_BUILD_FAILED}"
  fi
  echo "✅ iOS 无签名构建成功"
  echo "   产物：${PROJECT_ROOT}/${ARTIFACT}（未签名，不可安装）"
else
  echo "ℹ️  已设置 TEAM_ID=${TEAM_ID}，执行签名 ipa 导出。"
  if [[ ! -f "${EXPORT_OPTIONS_PLIST}" ]]; then
    echo "❌ 缺少导出配置文件 ${EXPORT_OPTIONS_PLIST}。"
    exit "${EXIT_BUILD_FAILED}"
  fi

  echo "──────── flutter build ipa --release ────────"
  if ! flutter build ipa --release --export-options-plist="${EXPORT_OPTIONS_PLIST}"; then
    echo "❌ iOS ipa 构建/导出失败（flutter build ipa 返回非 0）。"
    echo "   常见原因：TEAM_ID 与描述文件不匹配、证书缺失、ExportOptions.plist 的 method 与证书类型不符。"
    exit "${EXIT_BUILD_FAILED}"
  fi

  IPA_PATH=""
  for candidate in build/ios/ipa/*.ipa; do
    if [[ -f "${candidate}" ]]; then
      IPA_PATH="${candidate}"
      break
    fi
  done

  if [[ -z "${IPA_PATH}" ]]; then
    echo "❌ 构建命令返回 0，但 build/ios/ipa/ 下未找到 .ipa 产物。"
    echo "   按「禁伪造成功」铁律，此处判定为构建失败。"
    exit "${EXIT_BUILD_FAILED}"
  fi
  echo "✅ iOS ipa 构建成功"
  echo "   产物：${PROJECT_ROOT}/${IPA_PATH}"
fi

exit 0
