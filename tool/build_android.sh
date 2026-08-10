#!/usr/bin/env bash
# =============================================================================
# tool/build_android.sh —— Android Release 构建脚本（批次 E+ · T24）
#
# 设计铁律：
#   1. 第一步 source tool/flutter_env.sh。
#   2. 工具链前置检查：flutter / java / Android SDK；缺失 → 退出码 2 + 明确提示。
#   3. 严禁伪造成功：只有构建返回 0 **且** 产物真实存在才打印「构建成功」。
#
# 退出码约定：
#   0 = 构建成功
#   1 = 构建失败
#   2 = 工具链缺失（Flutter / JDK / Android SDK）
#
# 可选环境变量：
#   ANDROID_BUILD_TARGET  apk（默认）| appbundle
#   ANDROID_HOME / ANDROID_SDK_ROOT  Android SDK 路径
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=tool/flutter_env.sh
source "${SCRIPT_DIR}/flutter_env.sh"

cd "${PROJECT_ROOT}"

readonly EXIT_BUILD_FAILED=1
readonly EXIT_TOOLCHAIN_MISSING=2

# 与 build_macos.sh / build_ios.sh 保持一致：本地变量文件存在则载入
# （tool/signing.env 不入库，模板见 tool/signing.env.example）。
if [[ -f "${SCRIPT_DIR}/signing.env" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/signing.env"
fi

ANDROID_BUILD_TARGET="${ANDROID_BUILD_TARGET:-apk}"

echo "════════ Android Release 构建（target=${ANDROID_BUILD_TARGET}）════════"
echo "项目根目录：${PROJECT_ROOT}"

# ── 1. 工具链前置检查：flutter ─────────────────────────────────────────────
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ 工具链缺失：找不到命令 'flutter'。"
  echo "   请确认 Flutter SDK 已安装且在 PATH 中。"
  exit "${EXIT_TOOLCHAIN_MISSING}"
fi

# ── 2. 工具链前置检查：java ───────────────────────────────────────────────
if ! command -v java >/dev/null 2>&1; then
  echo "❌ 工具链缺失：找不到命令 'java'。"
  echo "   Android Gradle 构建需要 JDK 17（推荐 Temurin / Microsoft OpenJDK 17）。"
  echo "   安装后请设置 JAVA_HOME，例如："
  echo "     export JAVA_HOME=\"\$(/usr/libexec/java_home -v 17)\""
  exit "${EXIT_TOOLCHAIN_MISSING}"
fi

java_version_output=""
if ! java_version_output="$(java -version 2>&1)"; then
  echo "❌ 工具链异常：'java -version' 执行失败。"
  printf '     %s\n' "${java_version_output:-<无输出>}"
  exit "${EXIT_TOOLCHAIN_MISSING}"
fi
echo "✔ JDK 可用："
printf '    %s\n' "${java_version_output}" | head -1

# ── 3. 工具链前置检查：Android SDK ────────────────────────────────────────
ANDROID_SDK_DIR="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"

# 未显式设置时，尝试 macOS / Linux 的默认安装位置（探测到才用，探测不到不猜）。
if [[ -z "${ANDROID_SDK_DIR}" ]]; then
  for candidate in "${HOME}/Library/Android/sdk" "${HOME}/Android/Sdk"; do
    if [[ -d "${candidate}" ]]; then
      ANDROID_SDK_DIR="${candidate}"
      echo "ℹ️  ANDROID_HOME 未设置，探测到默认 SDK 目录：${ANDROID_SDK_DIR}"
      break
    fi
  done
fi

if [[ -z "${ANDROID_SDK_DIR}" || ! -d "${ANDROID_SDK_DIR}" ]]; then
  echo "❌ 工具链缺失：未找到 Android SDK。"
  echo "   ANDROID_HOME     = ${ANDROID_HOME:-<未设置>}"
  echo "   ANDROID_SDK_ROOT = ${ANDROID_SDK_ROOT:-<未设置>}"
  echo "   请安装 Android SDK（Android Studio 或 cmdline-tools）后设置："
  echo "     export ANDROID_HOME=\"\$HOME/Library/Android/sdk\""
  echo "     export PATH=\"\$ANDROID_HOME/platform-tools:\$PATH\""
  exit "${EXIT_TOOLCHAIN_MISSING}"
fi

export ANDROID_HOME="${ANDROID_SDK_DIR}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_DIR}"
echo "✔ Android SDK：${ANDROID_SDK_DIR}"

# ── 4. 依赖拉取 ───────────────────────────────────────────────────────────
echo "──────── flutter pub get ────────"
if ! flutter pub get; then
  echo "❌ flutter pub get 失败（依赖未就绪，终止构建）。"
  exit "${EXIT_BUILD_FAILED}"
fi

# ── 5. 构建 ───────────────────────────────────────────────────────────────
case "${ANDROID_BUILD_TARGET}" in
  apk)
    echo "──────── flutter build apk --release ────────"
    if ! flutter build apk --release; then
      echo "❌ Android APK 构建失败（flutter build apk --release 返回非 0）。"
      exit "${EXIT_BUILD_FAILED}"
    fi
    ARTIFACT="build/app/outputs/flutter-apk/app-release.apk"
    ;;
  appbundle)
    echo "──────── flutter build appbundle --release ────────"
    if ! flutter build appbundle --release; then
      echo "❌ Android AAB 构建失败（flutter build appbundle --release 返回非 0）。"
      exit "${EXIT_BUILD_FAILED}"
    fi
    ARTIFACT="build/app/outputs/bundle/release/app-release.aab"
    ;;
  *)
    echo "❌ 参数错误：ANDROID_BUILD_TARGET 只支持 apk | appbundle，当前为 '${ANDROID_BUILD_TARGET}'。"
    exit "${EXIT_BUILD_FAILED}"
    ;;
esac

# ── 6. 产物校验 ───────────────────────────────────────────────────────────
if [[ ! -f "${ARTIFACT}" ]]; then
  echo "❌ 构建命令返回 0，但未找到产物 ${ARTIFACT}。"
  echo "   按「禁伪造成功」铁律，此处判定为构建失败。"
  exit "${EXIT_BUILD_FAILED}"
fi

echo "✅ Android Release 构建成功"
echo "   产物：${PROJECT_ROOT}/${ARTIFACT}"
exit 0
