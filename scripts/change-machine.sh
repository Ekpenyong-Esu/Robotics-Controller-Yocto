#!/bin/bash

# Script to change the target machine configuration for the Yocto build

# Set color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directory
SCRIPT_PATH=$(readlink -f ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname $SCRIPT_PATH)
PROJECT_DIR=$(dirname $SCRIPT_DIR)
LOCAL_CONF="$PROJECT_DIR/build/conf/local.conf"

# Function to show help
show_help() {
    echo -e "\n${YELLOW}Usage:${NC} $0 [OPTION]"
    echo -e "\nOptions:"
    echo -e "  beaglebone    Configure for BeagleBone Black"
    echo -e "  rpi3          Configure for Raspberry Pi 3"
    echo -e "  rpi4          Configure for Raspberry Pi 4"
    echo -e "  qemu          Configure for QEMU testing"
    echo -e "  help          Show this help message"
    echo
}

# Check for help first
if [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Check if local.conf exists
if [ ! -f "$LOCAL_CONF" ]; then
    echo -e "${RED}Error:${NC} local.conf not found at $LOCAL_CONF"
    echo -e "Please run setup-yocto-env.sh first to initialize the build environment."
    exit 1
fi

# Print current machine setting
CURRENT_MACHINE=$(grep -P '^MACHINE \?=' "$LOCAL_CONF" | cut -d '"' -f 2)
echo -e "${BLUE}Current machine configuration:${NC} $CURRENT_MACHINE"

# Function to update local.conf
update_machine() {
    local machine=$1

    # Backup local.conf
    cp "$LOCAL_CONF" "${LOCAL_CONF}.bak"

    # Replace machine configuration
    sed -i "s/^MACHINE \?=.*$/MACHINE \?= \"${machine}\"/" "$LOCAL_CONF"

    echo -e "${GREEN}MACHINE configuration updated to:${NC} $machine"
    echo -e "A backup of your previous configuration was saved to ${LOCAL_CONF}.bak"
    echo -e "\n${BLUE}To build with this configuration, run:${NC}"
    echo -e "./scripts/build.sh"
}

# Handle command line argument
case "$1" in
    beaglebone)
        update_machine "beaglebone-robotics"
        ;;
    rpi3)
        # Check if meta-raspberrypi layer exists
        if [ ! -d "$PROJECT_DIR/build/meta-raspberrypi" ]; then
            echo -e "${YELLOW}Warning:${NC} meta-raspberrypi layer not found."
            echo -e "Do you want to clone the meta-raspberrypi layer now? (required for Raspberry Pi builds)"
            read -p "Clone meta-raspberrypi? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                echo -e "${BLUE}Cloning meta-raspberrypi layer...${NC}"
                git clone git://git.yoctoproject.org/meta-raspberrypi -b scarthgap "$PROJECT_DIR/build/meta-raspberrypi"
                echo -e "${GREEN}meta-raspberrypi cloned successfully!${NC}"

                # Add meta-raspberrypi to bblayers.conf if it exists
                if [ -f "$PROJECT_DIR/build/conf/bblayers.conf" ]; then
                    if ! grep -q "meta-raspberrypi" "$PROJECT_DIR/build/conf/bblayers.conf"; then
                        echo -e "${BLUE}Adding meta-raspberrypi to bblayers.conf...${NC}"
                        sed -i "/meta-robotics/i\\  \\${TOPDIR}\\/../meta-raspberrypi \\\\" "$PROJECT_DIR/build/conf/bblayers.conf"
                    fi
                fi
            else
                echo -e "${YELLOW}Skipping meta-raspberrypi clone. Build for Raspberry Pi may fail.${NC}"
            fi
        fi
        update_machine "raspberrypi3"
        ;;
    rpi4)
        # Check if meta-raspberrypi layer exists
        if [ ! -d "$PROJECT_DIR/build/meta-raspberrypi" ]; then
            echo -e "${YELLOW}Warning:${NC} meta-raspberrypi layer not found."
            echo -e "Do you want to clone the meta-raspberrypi layer now? (required for Raspberry Pi builds)"
            read -p "Clone meta-raspberrypi? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                echo -e "${BLUE}Cloning meta-raspberrypi layer...${NC}"
                git clone git://git.yoctoproject.org/meta-raspberrypi -b scarthgap "$PROJECT_DIR/build/meta-raspberrypi"
                echo -e "${GREEN}meta-raspberrypi cloned successfully!${NC}"

                # Add meta-raspberrypi to bblayers.conf if it exists
                if [ -f "$PROJECT_DIR/build/conf/bblayers.conf" ]; then
                    if ! grep -q "meta-raspberrypi" "$PROJECT_DIR/build/conf/bblayers.conf"; then
                        echo -e "${BLUE}Adding meta-raspberrypi to bblayers.conf...${NC}"
                        sed -i "/meta-robotics/i\\  \\${TOPDIR}\\/../meta-raspberrypi \\\\" "$PROJECT_DIR/build/conf/bblayers.conf"
                    fi
                fi
            else
                echo -e "${YELLOW}Skipping meta-raspberrypi clone. Build for Raspberry Pi may fail.${NC}"
            fi
        fi
        update_machine "rpi4-robotics"
        ;;
    qemu)
        update_machine "qemu-robotics"
        ;;
    *)
        echo -e "${RED}Unknown option:${NC} $1"
        show_help
        exit 1
        ;;
esac

exit 0
