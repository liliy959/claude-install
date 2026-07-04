# =============================================================
#  Claude Code 一键安装脚本 (适用于国内网络)
#  用法: irm https://liliy959.github.io/claude-install/cc.ps1 | iex
# =============================================================

$ErrorActionPreference = "Stop"

# ---------- 配置区 ----------
# GitHub 镜像加速站（按顺序尝试，都失败则直连）
$MIRRORS = @(
    "https://ghfast.top",           # 国内可用的 GitHub 加速
    "https://ghproxy.net",
    "https://github.moeyy.xyz"
)
# ---------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   Claude Code 安装脚本" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 判断操作系统
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    $platform = "win"
    Write-Host "[✓] 检测到 Windows 系统" -ForegroundColor Green
} elseif ($IsMacOS) {
    $platform = "mac"
    Write-Host "[✓] 检测到 macOS 系统" -ForegroundColor Green
} elseif ($IsLinux) {
    $platform = "linux"
    Write-Host "[✓] 检测到 Linux 系统" -ForegroundColor Green
} else {
    Write-Host "[✗] 不支持的操作系统" -ForegroundColor Red
    exit 1
}

# ---------- 1. 获取最新版本 ----------
Write-Host "`n[1/3] 正在获取最新版本号..." -ForegroundColor Yellow

try {
    $apiUrl = "https://api.github.com/repos/anthropics/claude-code/releases/latest"
    $releaseInfo = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 15 -UseBasicParsing
    $version = $releaseInfo.tag_name
    Write-Host "  → 最新版本: $version" -ForegroundColor Green
} catch {
    Write-Host "[✗] 无法访问 GitHub API，请检查网络或使用代理" -ForegroundColor Red
    Write-Host "  提示: 可先设置代理 `set HTTP_PROXY=http://127.0.0.1:7890`" -ForegroundColor DarkYellow
    exit 1
}

# ---------- 2. 找到对应的安装包 ----------
Write-Host "`n[2/3] 正在匹配安装包..." -ForegroundColor Yellow

$assets = $releaseInfo.assets

switch ($platform) {
    "win" {
        $pattern = "\.exe$"
        $installType = "exe"
    }
    "mac" {
        $pattern = "darwin|\.pkg$"
        $installType = "pkg"
    }
    "linux" {
        $pattern = "linux|\.deb$"
        $installType = "deb"
    }
}

$asset = $assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1

if (-not $asset) {
    Write-Host "[✗] 未找到适合当前系统的安装包" -ForegroundColor Red
    Write-Host "  可用安装包列表:" -ForegroundColor DarkYellow
    $assets | ForEach-Object { Write-Host "    $($_.name)" -ForegroundColor DarkYellow }
    exit 1
}

$fileName = $asset.name
$originalUrl = $asset.browser_download_url
Write-Host "  → 安装包: $fileName" -ForegroundColor Green

# ---------- 3. 下载（走镜像加速） ----------
Write-Host "`n[3/3] 正在下载安装包..." -ForegroundColor Yellow
$downloadPath = Join-Path $env:TEMP $fileName

# 提取原始下载链接的相对路径用于拼接镜像地址
# GitHub release URL 格式: https://github.com/.../releases/download/vX.Y.Z/file
$relativePath = $originalUrl -replace "https://github.com/", ""

function Download-File {
    param([string]$Url, [string]$OutFile)

    try {
        Write-Host "  → $Url" -ForegroundColor Gray
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -TimeoutSec 600 -UseBasicParsing
        $ProgressPreference = 'Continue'

        # 验证文件是否有效
        if ((Get-Item $OutFile).Length -gt 1024) {
            return $true
        }
    } catch {
        Write-Host "  ✗ 该地址下载失败，尝试下一个..." -ForegroundColor DarkYellow
    }
    return $false
}

$downloaded = $false

# 先尝试镜像
foreach ($mirror in $MIRRORS) {
    $mirrorUrl = "$mirror/$relativePath"
    if (Download-File -Url $mirrorUrl -OutFile $downloadPath) {
        Write-Host "  ✓ 下载成功 (via 镜像)" -ForegroundColor Green
        $downloaded = $true
        break
    }
}

# 镜像都失败则直连
if (-not $downloaded) {
    Write-Host "  → 镜像均失败，正在直连 GitHub..." -ForegroundColor DarkYellow
    if (-not (Download-File -Url $originalUrl -OutFile $downloadPath)) {
        Write-Host "[✗] 下载失败，请手动安装" -ForegroundColor Red
        Write-Host "  手动下载地址: $originalUrl" -ForegroundColor DarkYellow
        Write-Host "  或访问: https://github.com/anthropics/claude-code/releases" -ForegroundColor DarkYellow
        exit 1
    }
    Write-Host "  ✓ 下载成功 (直连)" -ForegroundColor Green
}

# ---------- 4. 安装 ----------
Write-Host "`n正在进行安装..." -ForegroundColor Cyan

switch ($platform) {
    "win" {
        Write-Host "  启动安装程序，请按提示完成安装..." -ForegroundColor Yellow
        Start-Process -FilePath $downloadPath -Wait
    }
    "mac" {
        Write-Host "  请双击打开下载的 pkg 文件完成安装..." -ForegroundColor Yellow
        Start-Process "open" -ArgumentList $downloadPath
    }
    "linux" {
        Write-Host "  正在使用 dpkg 安装..." -ForegroundColor Yellow
        sudo dpkg -i $downloadPath
    }
}

# 清理
Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   安装完成！输入 claude 开始使用" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
