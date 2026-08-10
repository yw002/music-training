#!/usr/bin/env bash
# =============================================================================
# tool/verify_all.sh —— 总验证入口（批次 E+ · T24）
#
# 依次执行：
#   1. flutter analyze
#   2. flutter test（逐目录 -j 1，避免并发下音频/文件测试互相干扰）
#   3. 四端构建：macOS / iOS / Android / Windows
#
# 设计铁律（架构 §9.4.3 / §8 风险点 2）：
#   - 每步失败**如实记录并继续**，最后统一汇总，一次运行拿到完整全景。
#   - 区分三态：✅ 通过 / ⚠️ 因工具链缺失跳过（退出码 2）/ ❌ 真失败（其它非 0）。
#   - **绝不伪造任何一步成功**：所有结论来自子命令真实退出码。
#
# 整体退出码：
#   0 = 无真失败（可能含 ⚠️ 跳过项，已在汇总中明确标 skipped）
#   1 = 存在至少一个 ❌ 真失败
#
# 注意：本脚本刻意 **不使用 set -e**（需要失败后继续跑完剩余步骤）。
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=tool/flutter_env.sh
source "${SCRIPT_DIR}/flutter_env.sh"

cd "${PROJECT_ROOT}"

RESULTS=()
FAIL_COUNT=0
SKIP_COUNT=0
PASS_COUNT=0

# run_step <名称> <命令...>
# 记录三态结果，不中断后续步骤。
run_step() {
  local name="$1"
  shift
  echo ""
  echo "──────── ${name} ────────"
  echo "\$ $*"

  local code=0
  "$@" || code=$?

  if [[ "${code}" -eq 0 ]]; then
    RESULTS+=("✅ PASS    ${name}")
    PASS_COUNT=$((PASS_COUNT + 1))
  elif [[ "${code}" -eq 2 ]]; then
    RESULTS+=("⚠️  SKIPPED ${name} —— 工具链缺失，未执行（非代码问题，退出码 2）")
    SKIP_COUNT=$((SKIP_COUNT + 1))
  else
    RESULTS+=("❌ FAIL    ${name} —— 失败（退出码 ${code}）")
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  return 0
}

# record_skip <名称> <原因>
# 用于本机结构性无法执行、且不适合以子进程探测的步骤（如 Windows 构建）。
record_skip() {
  local name="$1"
  local reason="$2"
  echo ""
  echo "──────── ${name} ────────"
  echo "⚠️  未执行：${reason}"
  RESULTS+=("⚠️  SKIPPED ${name} —— ${reason}")
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

echo "════════════════════════════════════════════"
echo " interval_ear 全量验证 verify_all.sh"
echo " 项目根目录：${PROJECT_ROOT}"
echo " 开始时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════"

# ── 0. flutter 可用性（缺失则整体无意义，直接退出 2）───────────────────────
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ 工具链缺失：找不到命令 'flutter'，无法进行任何验证。"
  echo "   请确认 Flutter SDK 已安装且在 PATH 中。"
  exit 2
fi

# ── 1. 依赖 ───────────────────────────────────────────────────────────────
run_step "依赖拉取 flutter pub get" flutter pub get

# ── 2. 静态分析 ───────────────────────────────────────────────────────────
run_step "静态分析 flutter analyze" flutter analyze

# ── 3. 单元测试（逐目录 -j 1）─────────────────────────────────────────────
TEST_DIRS=()
for dir in test/*/; do
  if [[ -d "${dir}" ]]; then
    TEST_DIRS+=("${dir%/}")
  fi
done

if [[ "${#TEST_DIRS[@]}" -eq 0 ]]; then
  record_skip "单元测试" "test/ 下未发现任何子目录"
else
  for dir in "${TEST_DIRS[@]}"; do
    run_step "单元测试 ${dir}" flutter test "${dir}" -j 1
  done
fi

# test/ 根目录下的散装测试文件（若有）单独跑一轮
ROOT_TESTS=()
for f in test/*_test.dart; do
  if [[ -f "${f}" ]]; then
    ROOT_TESTS+=("${f}")
  fi
done
if [[ "${#ROOT_TESTS[@]}" -gt 0 ]]; then
  run_step "单元测试 test/(根目录)" flutter test "${ROOT_TESTS[@]}" -j 1
fi

# ── 4. 四端构建 ───────────────────────────────────────────────────────────
HOST_OS="$(uname -s 2>/dev/null || echo unknown)"

if [[ "${HOST_OS}" == "Darwin" ]]; then
  run_step "macOS 构建 tool/build_macos.sh" bash "${SCRIPT_DIR}/build_macos.sh"
  run_step "iOS 构建 tool/build_ios.sh"     bash "${SCRIPT_DIR}/build_ios.sh"
else
  record_skip "macOS 构建" "当前宿主为 ${HOST_OS}，macOS/iOS 构建必须在 macOS 主机执行"
  record_skip "iOS 构建"   "当前宿主为 ${HOST_OS}，macOS/iOS 构建必须在 macOS 主机执行"
fi

run_step "Android 构建 tool/build_android.sh" bash "${SCRIPT_DIR}/build_android.sh"

record_skip "Windows 构建" \
  "需在 Windows 主机执行 powershell -ExecutionPolicy Bypass -File tool\\build_windows.ps1"

# ── 5. 汇总 ───────────────────────────────────────────────────────────────
echo ""
echo "════════════════ 汇总 ════════════════"
if [[ "${#RESULTS[@]}" -gt 0 ]]; then
  printf '%s\n' "${RESULTS[@]}"
fi
echo "──────────────────────────────────────"
echo "通过 ${PASS_COUNT} 项 / 跳过 ${SKIP_COUNT} 项（工具链或宿主缺失）/ 失败 ${FAIL_COUNT} 项"
echo "结束时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo "══════════════════════════════════════"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  echo "结论：存在真实失败，需修复（退出码 1）。"
  exit 1
fi

if [[ "${SKIP_COUNT}" -gt 0 ]]; then
  echo "结论：无真实失败；有 ${SKIP_COUNT} 项因环境缺失被标记为 SKIPPED，"
  echo "      这些项**未经验证**，请在对应环境自行执行后再下结论。"
fi
exit 0
