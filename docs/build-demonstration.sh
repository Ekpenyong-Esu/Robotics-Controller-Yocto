#!/bin/bash

# =================================================================
# YOCTO ROBOTICS CONTROLLER BUILD DEMONSTRATION SCRIPT
# =================================================================
# This script demonstrates the complete build process
# from environment setup to image generation
# =================================================================

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Current directory
SCRIPT_PATH=$(readlink -f ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname $SCRIPT_PATH)
PROJECT_DIR=$(dirname $SCRIPT_DIR)

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}====================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}====================================================================${NC}\n"
}

# Function to print steps
print_step() {
    echo -e "\n${GREEN}➤ $1${NC}"
}

# Function to print commands
print_command() {
    echo -e "${YELLOW}$ $1${NC}"
}

# Function to simulate command execution
simulate_command() {
    print_command "$1"
    echo -e "${YELLOW}Simulating: ${NC}$1"
}

# Display introduction
print_header "ROBOTICS CONTROLLER YOCTO BUILD DEMONSTRATION"

echo -e "This script demonstrates the entire build process for the Robotics Controller"
echo -e "using the Yocto Project build system. It will show each step from environment"
echo -e "setup to building and flashing the image."
echo -e "\n${RED}NOTE: This is a demonstration script. Commands are shown but not executed.${NC}"

# Step 1: Initial setup
print_header "STEP 1: INITIAL SETUP"

print_step "Install host dependencies"
print_command "sudo apt update"
print_command "sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential \\"
print_command "     chrpath socat cpio python3 python3-pip python3-pexpect xz-utils \\"
print_command "     debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa \\"
print_command "     libsdl1.2-dev xterm python3-subunit mesa-common-dev zstd liblz4-tool"

print_step "Navigate to project directory"
print_command "cd /path/to/Robotics-Controller-Yocto"

# Step 2: Environment setup
print_header "STEP 2: ENVIRONMENT SETUP"

print_step "Source the setup script to initialize build environment"
print_command "source ./setup-yocto-env.sh"

echo -e "\nThe script will prompt you to clone required repositories if they don't exist:"
echo -e "  - Poky (Yocto Project reference distribution)"
echo -e "  - meta-openembedded (collection of useful layers)"
echo -e "  - meta-raspberrypi (for Raspberry Pi targets)"

print_step "What happens during setup:"
echo -e "1. Repositories are cloned from upstream sources"
echo -e "2. Yocto build environment is initialized"
echo -e "3. meta-robotics layer is added to bblayers.conf"
echo -e "4. Initial machine configuration is set"

# Step 3: Switching machine configurations
print_header "STEP 3: SELECTING TARGET MACHINE"

print_step "View available machine options"
print_command "./scripts/change-machine.sh help"

print_step "Select BeagleBone Black target"
print_command "./scripts/change-machine.sh beaglebone"
echo -e "This updates local.conf to use the beaglebone-robotics machine configuration."

print_step "Alternatively, select Raspberry Pi 4 target"
print_command "./scripts/change-machine.sh rpi4"
echo -e "This ensures meta-raspberrypi layer is available and updates local.conf."

print_step "For virtual testing, select QEMU target"
print_command "./scripts/change-machine.sh qemu"
echo -e "This configures the build for the QEMU virtual machine target."

# Step 4: Building the image
print_header "STEP 4: BUILDING THE IMAGE"

print_step "Build using the build script (recommended)"
print_command "./scripts/build.sh"

echo -e "\nBuild script options:"
echo -e "  --clean      : Perform clean build (removes existing build directory)"
echo -e "  --verbose    : Enable verbose output"
echo -e "  --jobs N     : Set number of parallel build jobs"

print_step "Alternatively, build directly with BitBake"
print_command "bitbake robotics-image"

print_step "Expected build process:"
echo -e "1. Fetching sources        (~15 minutes)"
echo -e "2. Extracting and patching (~10 minutes)"
echo -e "3. Configuration           (~5 minutes)"
echo -e "4. Compilation             (~60-120 minutes)"
echo -e "5. Package creation        (~15 minutes)"
echo -e "6. Image generation        (~10 minutes)"

print_step "Build output location"
print_command "ls -l build/tmp/deploy/images/<machine-name>/"

# Step 5: Flashing the image
print_header "STEP 5: FLASHING THE IMAGE"

print_step "Insert SD card and identify device path"
print_command "lsblk"
echo -e "\n${RED}CAUTION: Be absolutely certain of your device path!${NC}"
echo -e "${RED}Using the wrong device path can overwrite your system drives!${NC}"

print_step "Flash image to SD card for BeagleBone"
print_command "./scripts/flash.sh --target bbb --device /dev/sdX"

print_step "Flash image to SD card for Raspberry Pi"
print_command "./scripts/flash.sh --target rpi4 --device /dev/sdX"

print_step "Safely eject the SD card"
print_command "sync"
print_command "sudo eject /dev/sdX"

# Step 6: Boot and verification
print_header "STEP 6: BOOTING AND VERIFICATION"

print_step "Insert SD card into target device and power on"

print_step "Connect via serial console"
print_command "screen /dev/ttyUSB0 115200"

print_step "Or SSH into the device when it boots"
print_command "ssh root@<device-ip>"
echo -e "Default password is 'robotics'"

print_step "Verify system is running correctly"
print_command "systemctl status robotics-controller"

# Conclusion
print_header "COMPLETE BUILD PROCESS OVERVIEW"

echo -e "You have now seen the complete process for building and deploying"
echo -e "the Robotics Controller image using the Yocto Project build system."
echo -e "\nKey files and directories:"
echo -e "  - build/tmp/deploy/images/              : Built images"
echo -e "  - build/tmp/work/                       : Work directories for packages"
echo -e "  - build/conf/local.conf                 : Local build configuration"
echo -e "  - build/conf/bblayers.conf              : Layer configuration"
echo -e "  - meta-robotics/                        : Custom layer for robotics"
echo -e "  - meta-robotics/recipes-core/images/    : Image recipes"
echo -e "\nFor more information, refer to the build-guide.md document."

print_header "END OF DEMONSTRATION"
