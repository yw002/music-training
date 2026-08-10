<#
.SYNOPSIS
    Windows Release 构建脚本（批次 E+ · T24）。

.DESCRIPTION
    对应 tool/build_macos.sh 的 Windows 版本。设计铁律与 bash 版一致：
      1. 先设置与 tool/flutter_env.sh 等价的镜像源环境变量
         （PowerShell 无法 source bash 脚本，故在此显式对齐，改动需同步两侧）。
      2. 工具链前置检查：flutter / Visual Studio C++ 生成工具；
         缺失 → exit 2（区别于 1 = 构建失败）。
      3. 严禁伪造成功：只有 flutter build 返回 0 且产物真实存在才输出「构建成功」。

.NOTES
    退出码：0 = 成功；1 = 构建失败；2 = 工具链缺失。
    需在 Windows 主机执行：  powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# PowerShell 7.4+ 默认让「原生命令非 0 退出码」直接抛异常，会绕过本脚本
# 精心设计的 1/2 退出码分流。此处显式关闭，改由我们自己检查 $LASTEXITCODE。
# （旧版 PowerShell 无此变量，赋值无副作用；StrictMode 只禁止读未定义变量。）
$PSNativeCommandUseErrorActionPreference = $false

$ExitBuildFailed      = 1
$ExitToolchainMissing = 2

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

Write-Host '════════ Windows Release 构建 ════════'
Write-Host "项目根目录：$ProjectRoot"

# ── 0. 与 tool/flutter_env.sh 对齐的镜像源环境变量 ─────────────────────────
# PowerShell 无法 source bash 脚本；此处保持与 tool/flutter_env.sh 同源同值。
$env:PUB_HOSTED_URL           = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

# 可选签名/自定义变量（tool\signing.env.ps1 不入库）
$SigningEnv = Join-Path $ScriptDir 'signing.env.ps1'
if (Test-Path -LiteralPath $SigningEnv) {
    Write-Host "ℹ️  载入本地变量：$SigningEnv"
    . $SigningEnv
}

# ── 1. 工具链前置检查：flutter ─────────────────────────────────────────────
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host '❌ 工具链缺失：找不到命令 ''flutter''。'
    Write-Host '   请安装 Flutter SDK 并把 flutter\bin 加入 PATH 后重试。'
    exit $ExitToolchainMissing
}

# ── 2. 工具链前置检查：Visual Studio C++ 生成工具 ─────────────────────────
# Flutter Windows 桌面构建依赖 MSVC v143 + Windows 10/11 SDK + CMake。
# 优先用 vswhere 精确探测「桌面 C++ 工作负载」，探测不到再退回 cl.exe。
$HasVisualStudio = $false

# ${env:ProgramFiles(x86)} 在极少数环境可能为空，先取值再判空，避免 Join-Path 抛错。
$ProgramFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
if ([string]::IsNullOrWhiteSpace($ProgramFilesX86)) {
    $ProgramFilesX86 = $env:ProgramFiles
}

if (-not [string]::IsNullOrWhiteSpace($ProgramFilesX86)) {
    $VsWhere = Join-Path $ProgramFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $VsWhere) {
        $VsPath = & $VsWhere -latest -products '*' `
            -requires 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' `
            -property installationPath 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($VsPath)) {
            $HasVisualStudio = $true
            Write-Host "✔ 检测到 Visual Studio（含桌面 C++ 工作负载）：$VsPath"
        }
    }
}

if (-not $HasVisualStudio) {
    if (Get-Command cl.exe -ErrorAction SilentlyContinue) {
        $HasVisualStudio = $true
        Write-Host '✔ 检测到 MSVC 编译器 cl.exe（已在开发者命令提示符环境中）。'
    }
}

if (-not $HasVisualStudio) {
    Write-Host '❌ 工具链缺失：未检测到 Visual Studio 的「使用 C++ 的桌面开发」工作负载。'
    Write-Host '   Flutter Windows 桌面构建需要：'
    Write-Host '     - Visual Studio 2022（Community 即可）'
    Write-Host '     - 工作负载：Desktop development with C++（含 MSVC v143 + Windows 10/11 SDK + CMake）'
    Write-Host '   安装后重开终端并重试；可用 flutter doctor -v 复核。'
    exit $ExitToolchainMissing
}

# ── 3. 依赖拉取 ───────────────────────────────────────────────────────────
Write-Host '──────── flutter pub get ────────'
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host '❌ flutter pub get 失败（依赖未就绪，终止构建）。'
    exit $ExitBuildFailed
}

# ── 4. 构建 ───────────────────────────────────────────────────────────────
Write-Host '──────── flutter build windows --release ────────'
& flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host '❌ Windows 构建失败（flutter build windows --release 返回非 0）。'
    Write-Host '   请查看上方 MSBuild / CMake 报错原文，不要忽略。'
    exit $ExitBuildFailed
}

# ── 5. 产物校验：命令返回 0 ≠ 产物存在，必须实测 ──────────────────────────
$ReleaseDir = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
$ExePath    = Join-Path $ReleaseDir 'interval_ear.exe'

if (-not (Test-Path -LiteralPath $ExePath)) {
    # 回退：产物名可能随 BINARY_NAME 变化，扫描目录下任意 exe。
    $Found = $null
    if (Test-Path -LiteralPath $ReleaseDir) {
        $Found = Get-ChildItem -LiteralPath $ReleaseDir -Filter '*.exe' -File -ErrorAction SilentlyContinue |
                 Select-Object -First 1
    }
    if ($null -eq $Found) {
        Write-Host "❌ 构建命令返回 0，但未在 $ReleaseDir 找到 .exe 产物。"
        Write-Host '   按「禁伪造成功」铁律，此处判定为构建失败。'
        exit $ExitBuildFailed
    }
    $ExePath = $Found.FullName
}

Write-Host '✅ Windows Release 构建成功'
Write-Host "   产物：$ExePath"
exit 0
