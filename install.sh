#!/usr/bin/env bash
# =============================================================
#  Claude Code 一键安装脚本 (macOS / Linux)
#  用法: curl -fsSL https://liliy959.github.io/claude-install/install.sh | bash
# =============================================================
set -e

# ---------- 配置 ----------
MIRRORS=(
    "https://ghfast.top"
    "https://ghproxy.net"
    "https://github.moeyy.xyz"
)
# --------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Claude Code 安装脚本${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 判断系统
OS="$(uname -s)"
case "$OS" in
    Darwin)
        PLATFORM="mac"
        echo -e "${GREEN}[✓] 检测到 macOS 系统${NC}"
        ;;
    Linux)
        PLATFORM="linux"
        echo -e "${GREEN}[✓] 检测到 Linux 系统${NC}"
        ;;
    *)
        echo -e "${RED}[✗] 不支持的操作系统: $OS${NC}"
        exit 1
        ;;
esac

# ---------- 1. 获取最新版本 ----------
echo -e "\n${YELLOW}[1/3] 正在获取最新版本号...${NC}"

if command -v jq &>/dev/null; then
    RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/anthropics/claude-code/releases/latest" 2>/dev/null || true)
    if [ -z "$RELEASE_JSON" ]; then
        echo -e "${RED}[✗] 无法访问 GitHub API${NC}"
        exit 1
    fi
    VERSION=$(echo "$RELEASE_JSON" | jq -r '.tag_name')
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | test("linux|darwin|deb|pkg|tar.gz")) | .browser_download_url' | head -1)
else
    # 不依赖 jq 的备用方案
    RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/anthropics/claude-code/releases/latest" 2>/dev/null || true)
    VERSION=$(echo "$RELEASE_JSON" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*"' | grep -iE 'linux|darwin|deb|pkg|tar.gz' | head -1 | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')
fi

if [ -z "$VERSION" ]; then
    echo -e "${RED}[✗] 获取版本信息失败${NC}"
    exit 1
fi

echo -e "  → 最新版本: ${VERSION}"
FILENAME=$(basename "$DOWNLOAD_URL")
echo -e "  → 安装包: ${FILENAME}"

# ---------- 2. 下载 ----------
echo -e "\n${YELLOW}[2/3] 正在下载...${NC}"
TMPFILE="/tmp/${FILENAME}"

RELATIVE_PATH="${DOWNLOAD_URL#https://github.com/}"

download() {
    local url="$1"
    curl -fSL --connect-timeout 10 --max-time 600 -o "$TMPFILE" "$url" 2>/dev/null && return 0
    return 1
}

SUCCESS=false
for mirror in "${MIRRORS[@]}"; do
    MIRROR_URL="${mirror}/${RELATIVE_PATH}"
    echo -e "  → ${MIRROR_URL}"
    if download "$MIRROR_URL"; then
        echo -e "${GREEN}  ✓ 下载成功 (via 镜像)${NC}"
        SUCCESS=true
        break
    fi
done

if [ "$SUCCESS" = false ]; then
    echo -e "  → 镜像均失败，直连 GitHub..."
    if download "$DOWNLOAD_URL"; then
        echo -e "${GREEN}  ✓ 下载成功 (直连)${NC}"
    else
        echo -e "${RED}[✗] 下载失败${NC}"
        echo -e "  手动下载: ${DOWNLOAD_URL}"
        exit 1
    fi
fi

# ---------- 3. 安装 ----------
echo -e "\n${YELLOW}[3/3] 正在安装...${NC}"

case "$PLATFORM" in
    mac)
        if [[ "$FILENAME" == *.pkg ]]; then
            sudo installer -pkg "$TMPFILE" -target /
        elif [[ "$FILENAME" == *.tar.gz ]]; then
            sudo tar -xzf "$TMPFILE" -C /usr/local/bin/
        fi
        ;;
    linux)
        if [[ "$FILENAME" == *.deb ]]; then
            sudo dpkg -i "$TMPFILE"
        elif [[ "$FILENAME" == *.tar.gz ]]; then
            sudo tar -xzf "$TMPFILE" -C /usr/local/bin/
        fi
        ;;
esac

rm -f "$TMPFILE"

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}   安装完成！输入 claude 开始使用${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
