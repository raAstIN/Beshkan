#!/bin/bash

set -euo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO="raAstIN/Beshkan"
INSTALL_DIR="/usr/local/bin"

echo -e "${CYAN}${BOLD}Beshkan Installer${NC}"
echo ""

detect_os() {
    case "$(uname -s)" in
        Darwin*)  echo "macos" ;;
        Linux*)   echo "linux" ;;
        *)        echo "unknown" ;;
    esac
}

OS=$(detect_os)

if [ "$OS" = "unknown" ]; then
    echo -e "${RED}Error: Unsupported operating system.${NC}"
    echo "Beshkan supports macOS and Linux."
    echo "For Windows, download beshkan-windows.ps1 from the GitHub repository."
    exit 1
fi

echo -e "${BOLD}Detected OS:${NC} ${OS}"

if [ "$OS" = "macos" ]; then
    SCRIPT="beshkan-macos.sh"
    TARGET="beshkan"
elif [ "$OS" = "linux" ]; then
    SCRIPT="beshkan-linux.sh"
    TARGET="beshkan"
fi

echo -e "${BOLD}Installing:${NC} ${SCRIPT} -> ${INSTALL_DIR}/${TARGET}"
echo ""

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Creating ${INSTALL_DIR}...${NC}"
    sudo mkdir -p "$INSTALL_DIR"
fi

if command -v curl &>/dev/null; then
    DOWNLOAD_CMD="curl -fsSL"
elif command -v wget &>/dev/null; then
    DOWNLOAD_CMD="wget -qO-"
else
    echo -e "${RED}Error: Neither curl nor wget found.${NC}"
    echo "Please install curl or wget and try again."
    exit 1
fi

echo -e "${CYAN}Downloading ${SCRIPT}...${NC}"
$DOWNLOAD_CMD "https://raw.githubusercontent.com/${REPO}/main/${SCRIPT}" | sudo tee "${INSTALL_DIR}/${TARGET}" > /dev/null

sudo chmod +x "${INSTALL_DIR}/${TARGET}"

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo -e "Run ${CYAN}${BOLD}${TARGET}${NC} to get started."
echo -e "Use ${CYAN}${BOLD}${TARGET} --help${NC} for more options."
echo ""
