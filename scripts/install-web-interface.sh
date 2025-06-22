#!/bin/bash

# Script to install the web interface files to the target system

# Set up colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing Web Interface Files${NC}"

# Define paths
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_SRC_DIR="${ROOT_DIR}/src/web-interface"
TARGET_DIR="/usr/share/robotics-controller/www"

# Check if source directory exists
if [ ! -d "${WEB_SRC_DIR}" ]; then
    echo -e "${RED}Web interface source directory not found: ${WEB_SRC_DIR}${NC}"
    exit 1
fi

# Create target directory if it doesn't exist
if [ ! -d "${TARGET_DIR}" ]; then
    echo -e "${YELLOW}Creating target directory: ${TARGET_DIR}${NC}"
    mkdir -p "${TARGET_DIR}" || {
        echo -e "${RED}Failed to create target directory${NC}"
        exit 1
    }
fi

# Copy web interface files
echo -e "${YELLOW}Copying web interface files...${NC}"
cp -r "${WEB_SRC_DIR}"/* "${TARGET_DIR}" || {
    echo -e "${RED}Failed to copy web interface files${NC}"
    exit 1
}

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chmod -R 755 "${TARGET_DIR}" || {
    echo -e "${RED}Failed to set permissions${NC}"
    exit 1
}

echo -e "${GREEN}Web interface files installed successfully to ${TARGET_DIR}${NC}"
