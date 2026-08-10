#!/usr/bin/env bash
# =============================================================================
# tool/build_macos.sh —— macOS Release 构建脚本（批次 E+ · T24）
#
# 设计铁律（架构 §9.4.1 / §8 风险点 2）：
#   1. 第一步 source tool/flutter_env.sh（镜像源 + Xcode 环境）。
#   2. 先做工具链前置检查，缺工具链 → 退出码 2（区别于 1 = 构建失败）。
#   3. 严禁伪造成功：只有 flutter build 返回 0 **且** .app 产物真实存在，
#      才打印「构建成功」。
#
# 退出码约定：
#   0 = 构建成功（产物已落盘并校验存在）
#   1 = 构建失败（命令返回非 0，或产物缺失）
#   2 = 工具链缺失 / Xcode 许可未接受（非代码问题，可跳过）
#
# 可选环境变量（见 tool/signing.env.example）：
#   CODESIGN_IDENTITY  签名证书名；未设置 → 走本地临时签名
#   NOTARIZE_PROFILE   notarytool keychain profile 名；未设置 → 跳过公证
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=tool/flutter_env.sh
source "${SCRIPT_DIR}/flutter_env.sh"

cd "${PROJECT_ROOT}"

readonly EXIT_BUILD_FAILED=1
readonly EXIT_TOOLCHAIN_MISSING=2

# 可选签名变量（tool/signing.env 不入库）
if [[ -f "${SCRIPT_DIR}/signing.env" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/signing.env"
fi

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-}"

echo "════════ macOS Release 构建 ════════"
echo "项目根目录：${PROJECT_ROOT}"

# ── 1. 工具链前置检查：flutter ─────────────────────────────────────────────
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ 工具链缺失：找不到命令 'flutter'。"
  echo "   请确认 Flutter SDK 已安装且在 PATH 中，或在 tool/flutter_env.sh 内补充 PATH。"
  exit "${EXIT_TOOLCHAIN_MISSING}"
fi

# ── 2. 工具链前置检查：xcodebuild + Xcode 许可 ─────────────────────────────
# 说明：许可未接受时 `xcodebuild -version` 会返回非 0 并在输出里提到 license；
#      这里用非交互方式探测，绝不调用会挂起终端的交互式 sudo。
xcodebuild_output=""
xcodebuild_ok=1
if ! xcodebuild_output="$(xcodebuild -version 2>&1)"; then
  xcodebuild_ok=0
fi

if [[ "${xcodebuild_ok}" -ne 1 ]] \
   || printf '%s' "${xcodebuild_output}" | grep -qi 'license'; then
  echo "❌ 无法构建 macOS：xcodebuild 不可用或 Xcode 许可未接受。"
  echo "   xcodebuild 输出："
  printf '     %s\n' "${xcodebuild_output:-<无输出>}"
  echo "   当前 DEVELOPER_DIR = ${DEVELOPER_DIR:-<未设置，使用 xcode-select 默认值>}"
  echo "   当前 xcode-select  = $(xcode-select -p 2>/dev/null || echo '<不可用>')"
  echo "   请先执行: sudo xcodebuild -license accept"
  echo "   若指向 CommandLineTools，另需: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "   （可用 sudo xcodebuild -license status 查看当前许可状态）"
  exit "${EXIT_TOOLCHAIN_MISSING}"
fi

echo "✔ xcodebuild 可用："
printf '    %s\n' "${xcodebuild_output}"

# ── 3. 依赖拉取 ───────────────────────────────────────────────────────────
echo "──────── flutter pub get ────────"
if ! flutter pub get; then
  echo "❌ flutter pub get 失败（依赖未就绪，终止构建）。"
  exit "${EXIT_BUILD_FAILED}"
fi

# ── 4. 构建 ───────────────────────────────────────────────────────────────
echo "──────── flutter build macos --release ────────"
if [[ -n "${CODESIGN_IDENTITY}" ]]; then
  echo "ℹ️  使用签名证书：${CODESIGN_IDENTITY}"
else
  echo "ℹ️  未设置 CODESIGN_IDENTITY，走 Xcode 默认/本地临时签名。"
fi

if ! flutter build macos --release; then
  echo "❌ macOS 构建失败（flutter build macos --release 返回非 0）。"
  echo "   请查看上方 Xcode / Flutter 报错原文，不要忽略。"
  exit "${EXIT_BUILD_FAILED}"
fi

# ── 5. 产物校验：命令返回 0 ≠ 产物存在，必须实测 ──────────────────────────
APP_PATH=""
for candidate in build/macos/Build/Products/Release/*.app; do
  if [[ -d "${candidate}" ]]; then
    APP_PATH="${candidate}"
    break
  fi
done

if [[ -z "${APP_PATH}" ]]; then
  echo "❌ 构建命令返回 0，但 build/macos/Build/Products/Release/ 下未找到 .app 产物。"
  echo "   按「禁伪造成功」铁律，此处判定为构建失败。"
  exit "${EXIT_BUILD_FAILED}"
fi

echo "✅ macOS Release 构建成功"
echo "   产物：${PROJECT_ROOT}/${APP_PATH}"

# ── 6. 可选公证（需要 Apple ID 凭据，默认跳过）─────────────────────────────
if [[ -n "${NOTARIZE_PROFILE}" ]]; then
  echo "──────── 公证 notarytool ────────"
  ZIP_PATH="build/macos/app.zip"
  if ! ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"; then
    echo "❌ 公证打包失败（ditto）。"
    exit "${EXIT_BUILD_FAILED}"
  fi
  if ! xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARIZE_PROFILE}" --wait; then
    echo "❌ 公证提交失败（notarytool）。"
    exit "${EXIT_BUILD_FAILED}"
  fi
  if ! xcrun stapler staple "${APP_PATH}"; then
    echo "❌ 公证票据装订失败（stapler）。"
    exit "${EXIT_BUILD_FAILED}"
  fi
  echo "✅ 公证完成并已装订票据。"
else
  echo "ℹ️  未设置 NOTARIZE_PROFILE，跳过公证（产物仅可本机运行/分发需自行公证）。"
fi

exit 0
