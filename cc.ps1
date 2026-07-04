#Requires -Version 5.1
<#
.SYNOPSIS
Claude Code one-click install script (optimized for users in China)
.DESCRIPTION
Detects OS, downloads the latest Claude Code release via GitHub mirrors, and installs it.
.LINK
https://liliy959.github.io/claude-install
#>

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# ---- Mirror list (tried in order, fallback to direct) ----
$MIRRORS = @(
    "https://ghfast.top",
    "https://ghproxy.net",
    "https://github.moeyy.xyz"
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Claude Code Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---- Detect OS ----
if ($IsWindows -or ($env:OS -eq "Windows_NT")) {
    $platform = "win"
    Write-Host "[OK] Windows detected" -ForegroundColor Green
} elseif ($IsMacOS) {
    $platform = "mac"
    Write-Host "[OK] macOS detected" -ForegroundColor Green
} elseif ($IsLinux) {
    $platform = "linux"
    Write-Host "[OK] Linux detected" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Unsupported operating system" -ForegroundColor Red
    exit 1
}

# ---- Auto-detect proxy ----
Write-Host ""
Write-Host "[0/3] Auto-detecting proxy..." -ForegroundColor Yellow

$PROXY_CANDIDATES = @(
    $null,                              # direct connection first
    "http://127.0.0.1:7890",           # Clash default
    "http://127.0.0.1:7897",
    "http://127.0.0.1:10809",          # v2rayN default
    "http://127.0.0.1:1080",
    "http://127.0.0.1:8080"
)

# Also check env vars
if ($env:HTTP_PROXY)  { $PROXY_CANDIDATES = @($env:HTTP_PROXY) + $PROXY_CANDIDATES }
if ($env:HTTPS_PROXY) { $PROXY_CANDIDATES = @($env:HTTPS_PROXY) + $PROXY_CANDIDATES }

function Test-Proxy {
    param([string]$ProxyUri)
    $testUrl = "https://api.github.com"
    try {
        $req = [System.Net.WebRequest]::Create($testUrl)
        $req.Timeout = 5000
        if ($ProxyUri) {
            $req.Proxy = [System.Net.WebProxy]::new($ProxyUri)
        } else {
            $req.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        }
        $resp = $req.GetResponse()
        $resp.Close()
        return $true
    } catch { }
    return $false
}

$USE_PROXY = $null
$found = $false
foreach ($candidate in $PROXY_CANDIDATES) {
    if ($candidate) {
        Write-Host "  Trying $candidate ..." -ForegroundColor Gray
    } else {
        Write-Host "  Trying direct connection ..." -ForegroundColor Gray
    }
    if (Test-Proxy -ProxyUri $candidate) {
        $USE_PROXY = $candidate
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Host "[ERROR] Cannot reach GitHub. Please check your network or proxy." -ForegroundColor Red
    Write-Host "  If you have a proxy, set it first and retry:" -ForegroundColor DarkYellow
    Write-Host "  `$env:HTTPS_PROXY='http://127.0.0.1:YOUR_PORT'; irm https://liliy959.github.io/claude-install/cc.ps1 | iex" -ForegroundColor DarkYellow
    exit 1
}

if ($USE_PROXY) {
    Write-Host "  [OK] Using proxy: $USE_PROXY" -ForegroundColor Green
    $env:HTTP_PROXY = $USE_PROXY
    $env:HTTPS_PROXY = $USE_PROXY
} else {
    Write-Host "  [OK] Direct connection works" -ForegroundColor Green
}

# ---- Step 1: Fetch latest version info ----
Write-Host ""
Write-Host "[1/3] Fetching latest version..." -ForegroundColor Yellow

try {
    $apiUrl = "https://api.github.com/repos/anthropics/claude-code/releases/latest"
    $releaseInfo = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 15 -UseBasicParsing
    $version = $releaseInfo.tag_name
    Write-Host "  -> Latest: $version" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Cannot reach GitHub API. Check your network or proxy." -ForegroundColor Red
    exit 1
}

# ---- Step 2: Find the right installer ----
Write-Host ""
Write-Host "[2/3] Matching installer package..." -ForegroundColor Yellow

$assets = $releaseInfo.assets

switch ($platform) {
    "win"   { $pattern = "\.exe$" }
    "mac"   { $pattern = "darwin|\.pkg$" }
    "linux" { $pattern = "linux|\.deb$" }
}

$asset = $assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1

if (-not $asset) {
    Write-Host "[ERROR] No matching installer found for your system." -ForegroundColor Red
    Write-Host "  Available packages:" -ForegroundColor DarkYellow
    $assets | ForEach-Object { Write-Host "    $($_.name)" -ForegroundColor DarkYellow }
    exit 1
}

$fileName = $asset.name
$originalUrl = $asset.browser_download_url
Write-Host "  -> Package: $fileName" -ForegroundColor Green

# ---- Step 3: Download via mirrors ----
Write-Host ""
Write-Host "[3/3] Downloading..." -ForegroundColor Yellow
$downloadPath = Join-Path $env:TEMP $fileName

# Extract relative path from github.com URL for mirror URLs
$relativePath = $originalUrl -replace "https://github.com/", ""

function Test-Download {
    param([string]$Url, [string]$OutFile)
    try {
        Write-Host "  -> $Url" -ForegroundColor Gray
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -TimeoutSec 600 -UseBasicParsing
        $ProgressPreference = "Continue"
        if ((Get-Item $OutFile).Length -gt 1024) {
            return $true
        }
    } catch {
        Write-Host "  -- Failed, trying next..." -ForegroundColor DarkYellow
    }
    return $false
}

$downloaded = $false

# Try mirrors first
foreach ($mirror in $MIRRORS) {
    $mirrorUrl = "$mirror/$relativePath"
    if (Test-Download -Url $mirrorUrl -OutFile $downloadPath) {
        Write-Host "  [OK] Downloaded via mirror" -ForegroundColor Green
        $downloaded = $true
        break
    }
}

# Fallback to direct
if (-not $downloaded) {
    Write-Host "  -- Mirrors exhausted, trying direct connection..." -ForegroundColor DarkYellow
    if (-not (Test-Download -Url $originalUrl -OutFile $downloadPath)) {
        Write-Host "[ERROR] Download failed. Install manually:" -ForegroundColor Red
        Write-Host "  $originalUrl" -ForegroundColor DarkYellow
        Write-Host "  https://github.com/anthropics/claude-code/releases" -ForegroundColor DarkYellow
        exit 1
    }
    Write-Host "  [OK] Downloaded (direct)" -ForegroundColor Green
}

# ---- Step 4: Install ----
Write-Host ""
Write-Host "Installing..." -ForegroundColor Cyan

switch ($platform) {
    "win" {
        Write-Host "  Launching installer, follow the prompts..." -ForegroundColor Yellow
        Start-Process -FilePath $downloadPath -Wait
    }
    "mac" {
        Write-Host "  Opening pkg installer..." -ForegroundColor Yellow
        Start-Process "open" -ArgumentList $downloadPath
    }
    "linux" {
        Write-Host "  Installing via dpkg..." -ForegroundColor Yellow
        sudo dpkg -i $downloadPath
    }
}

Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Done! Type 'claude' to get started" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
