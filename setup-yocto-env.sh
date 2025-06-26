#!/bin/bash

# This script sets up the Yocto project environment for Robotics Controller
# You should source this script rather than executing it:
# source setup-yocto-env.sh

# Set color codes
GREEN='\033[0;32m'
RED='\033[0;31m'   # Added missing RED color code
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directory
SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_DIR="$SCRIPT_DIR"

# Function to initialize git repository
initialize_git_repo() {
    echo -e "${BLUE}Initializing git repository...${NC}"

    # Check if git is already initialized
    if [ -d "$PROJECT_DIR/.git" ]; then
        echo -e "${YELLOW}Git repository already initialized.${NC}"
        return
    fi

    # Initialize git repository
    git init "$PROJECT_DIR"

    # Create .gitignore file
    cat > "$PROJECT_DIR/.gitignore" << EOF
# Build directories
build/tmp/
build/cache/
build/sstate-cache/
build/downloads/
build/bitbake-cookerdaemon.log

# Editor files
*.swp
*~
.vscode/
.idea/

# Compiled files
*.o
*.so
*.a
*.pyc
__pycache__/

# Log files
*.log
EOF

    # Initial commit
    git -C "$PROJECT_DIR" add .
    git -C "$PROJECT_DIR" commit -m "Initial commit: Basic repository structure"

    echo -e "${GREEN}Git repository initialized successfully!${NC}"
}

# Function to create meta-layer structure
create_meta_layer() {
    echo -e "${BLUE}Creating meta-robotics layer structure...${NC}"

    # Create meta-robotics directory structure if it doesn't exist
    if [ ! -d "$PROJECT_DIR/meta-robotics" ]; then
        mkdir -p "$PROJECT_DIR/meta-robotics/conf"
        mkdir -p "$PROJECT_DIR/meta-robotics/recipes-core/images"
        mkdir -p "$PROJECT_DIR/meta-robotics/recipes-robotics/robotics-controller"
        mkdir -p "$PROJECT_DIR/meta-robotics/recipes-kernel/linux"
    fi

    # Create layer.conf if it doesn't exist
    if [ ! -f "$PROJECT_DIR/meta-robotics/conf/layer.conf" ]; then
        cat > "$PROJECT_DIR/meta-robotics/conf/layer.conf" << EOF
# We have a conf and classes directory, add to BBPATH
BBPATH .= ":\${LAYERDIR}"

# We have recipes-* directories, add to BBFILES
BBFILES += "\${LAYERDIR}/recipes-*/*/*.bb \\
            \${LAYERDIR}/recipes-*/*/*.bbappend"

BBFILE_COLLECTIONS += "robotics"
BBFILE_PATTERN_robotics = "^\\${LAYERDIR}/"
BBFILE_PRIORITY_robotics = "10"

LAYERDEPENDS_robotics = "core"
LAYERSERIES_COMPAT_robotics = "scarthgap"
EOF
    fi

    # Create machine configuration directory and beaglebone-robotics machine
    if [ ! -d "$PROJECT_DIR/meta-robotics/conf/machine" ]; then
        mkdir -p "$PROJECT_DIR/meta-robotics/conf/machine"

        # Create beaglebone-robotics.conf
        cat > "$PROJECT_DIR/meta-robotics/conf/machine/beaglebone-robotics.conf" << EOF
#@TYPE: Machine
#@NAME: BeagleBone Robotics
#@DESCRIPTION: Machine configuration for the BeagleBone Black with Robotics Controller

require conf/machine/include/ti-am335x.inc

KERNEL_DEVICETREE = "am335x-boneblack.dtb"
PREFERRED_PROVIDER_virtual/kernel = "linux-yocto"
PREFERRED_VERSION_linux-yocto = "6.1%"

MACHINE_FEATURES += "usbhost usbgadget wifi bluetooth"

MACHINE_EXTRA_RRECOMMENDS += "kernel-modules"

# Use the robotics controller overlay
KERNEL_MODULE_AUTOLOAD += "robotics_controller"
EOF
    fi

    # Create basic robotics image recipe
    if [ ! -f "$PROJECT_DIR/meta-robotics/recipes-core/images/robotics-image.bb" ]; then
        cat > "$PROJECT_DIR/meta-robotics/recipes-core/images/robotics-image.bb" << EOF
SUMMARY = "Robotics Controller Image"
DESCRIPTION = "A custom image for the Robotics Controller"
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "\\
    debug-tweaks \\
    dev-pkgs \\
    tools-debug \\
    tools-profile \\
    tools-sdk \\
    ssh-server-openssh \\
    hwcodecs \\
"

CORE_IMAGE_EXTRA_INSTALL += "\\
    packagegroup-core-boot \\
    packagegroup-core-full-cmdline \\
    kernel-modules \\
    robotics-controller \\
    openssh \\
    rsync \\
    git \\
    python3 \\
    python3-pip \\
    python3-robotics-libs \\
    nodejs \\
    nginx \\
"

# Add additional space to the rootfs for applications
IMAGE_ROOTFS_EXTRA_SPACE = "524288"
EOF
    fi

    # Create robotics-controller recipe
    mkdir -p "$PROJECT_DIR/meta-robotics/recipes-robotics/robotics-controller"

    if [ ! -f "$PROJECT_DIR/meta-robotics/recipes-robotics/robotics-controller/robotics-controller_1.0.bb" ]; then
        cat > "$PROJECT_DIR/meta-robotics/recipes-robotics/robotics-controller/robotics-controller_1.0.bb" << EOF
SUMMARY = "Robotics Controller Application"
DESCRIPTION = "Main application for the Robotics Controller platform"
SECTION = "robotics"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://\${WORKDIR}/git/LICENSE;md5=put-actual-md5sum-here"

SRC_URI = "git://github.com/yourusername/robotics-controller.git;protocol=https;branch=master"
SRCREV = "\${AUTOREV}"
PV = "1.0+git\${SRCPV}"

S = "\${WORKDIR}/git"

inherit cmake systemd

DEPENDS = "boost libwebsockets json-c"
RDEPENDS_\${PN} += "bash python3"

SYSTEMD_SERVICE_\${PN} = "robotics-controller.service"

do_install_append() {
    install -d \${D}\${systemd_unitdir}/system
    install -m 0644 \${S}/robotics-controller.service \${D}\${systemd_unitdir}/system/
}

FILES_\${PN} += "\${bindir}/* \${systemd_unitdir}/*"
EOF
    fi

    echo -e "${GREEN}Meta-robotics layer created successfully!${NC}"
}

# Function to create Buildroot external layer
create_buildroot_external() {
    echo -e "${BLUE}Setting up Buildroot external layer...${NC}"

    # Create external Buildroot directories
    mkdir -p "$PROJECT_DIR/build/buildroot-external"
    mkdir -p "$PROJECT_DIR/build/buildroot-external/board"
    mkdir -p "$PROJECT_DIR/build/buildroot-external/configs"
    mkdir -p "$PROJECT_DIR/build/buildroot-external/package"

    # Create external.desc
    if [ ! -f "$PROJECT_DIR/build/buildroot-external/external.desc" ]; then
        cat > "$PROJECT_DIR/build/buildroot-external/external.desc" << EOF
name: ROBOTICS_CONTROLLER
desc: External layer for Robotics Controller
EOF
    fi

    # Create external.mk
    if [ ! -f "$PROJECT_DIR/build/buildroot-external/external.mk" ]; then
        cat > "$PROJECT_DIR/build/buildroot-external/external.mk" << EOF
include \$(sort \$(wildcard \$(BR2_EXTERNAL_ROBOTICS_CONTROLLER_PATH)/package/*/*.mk))
EOF
    fi

    # Create Config.in
    if [ ! -f "$PROJECT_DIR/build/buildroot-external/Config.in" ]; then
        cat > "$PROJECT_DIR/build/buildroot-external/Config.in" << EOF
menu "Robotics Controller packages"
source "\$BR2_EXTERNAL_ROBOTICS_CONTROLLER_PATH/package/robotics-controller/Config.in"
source "\$BR2_EXTERNAL_ROBOTICS_CONTROLLER_PATH/package/web-interface/Config.in"
endmenu
EOF
    fi

    # Create a sample package for robotics-controller
    mkdir -p "$PROJECT_DIR/build/buildroot-external/package/robotics-controller"

    if [ ! -f "$PROJECT_DIR/build/buildroot-external/package/robotics-controller/Config.in" ]; then
        cat > "$PROJECT_DIR/build/buildroot-external/package/robotics-controller/Config.in" << EOF
config BR2_PACKAGE_ROBOTICS_CONTROLLER
    bool "robotics-controller"
    depends on BR2_PACKAGE_HOST_GO_TARGET_ARCH_SUPPORTS
    select BR2_PACKAGE_LIBWEBSOCKETS
    select BR2_PACKAGE_JSON_C
    help
      Robotics Controller main application

      https://github.com/yourusername/robotics-controller
EOF
    fi

    if [ ! -f "$PROJECT_DIR/build/buildroot-external/package/robotics-controller/robotics-controller.mk" ]; then
        cat > "$PROJECT_DIR/build/buildroot-external/package/robotics-controller/robotics-controller.mk" << EOF
################################################################################
#
# robotics-controller
#
################################################################################

ROBOTICS_CONTROLLER_VERSION = 1.0
ROBOTICS_CONTROLLER_SITE = \$(BR2_EXTERNAL_ROBOTICS_CONTROLLER_PATH)/package/robotics-controller/src
ROBOTICS_CONTROLLER_SITE_METHOD = local
ROBOTICS_CONTROLLER_LICENSE = MIT
ROBOTICS_CONTROLLER_LICENSE_FILES = LICENSE
ROBOTICS_CONTROLLER_DEPENDENCIES = libwebsockets json-c

define ROBOTICS_CONTROLLER_BUILD_CMDS
    \$(MAKE) \$(TARGET_CONFIGURE_OPTS) -C \$(@D) all
endef

define ROBOTICS_CONTROLLER_INSTALL_TARGET_CMDS
    \$(INSTALL) -D -m 0755 \$(@D)/robotics-controller \$(TARGET_DIR)/usr/bin/robotics-controller
    \$(INSTALL) -D -m 0644 \$(@D)/robotics-controller.service \$(TARGET_DIR)/usr/lib/systemd/system/robotics-controller.service
endef

define ROBOTICS_CONTROLLER_INSTALL_INIT_SYSTEMD
    \$(INSTALL) -D -m 644 \$(@D)/robotics-controller.service \$(TARGET_DIR)/usr/lib/systemd/system/robotics-controller.service
endef

\$(eval \$(generic-package))
EOF
    fi

    # Create package src directory and basic files
    mkdir -p "$PROJECT_DIR/build/buildroot-external/package/robotics-controller/src"

    echo -e "${GREEN}Buildroot external layer setup complete!${NC}"
}

# Function to create tools and scripts framework
create_tools_framework() {
    echo -e "${BLUE}Creating tools and scripts framework...${NC}"

    # Create scripts directory if it doesn't exist
    mkdir -p "$PROJECT_DIR/scripts"

    # Create build.sh
    if [ ! -f "$PROJECT_DIR/scripts/build.sh" ]; then
        cat > "$PROJECT_DIR/scripts/build.sh" << 'EOF'
#!/bin/bash

# Build script for Robotics Controller
# Usage: ./scripts/build.sh [target]

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

# Default target
TARGET=${1:-robotics-image}

# Setup build environment
source "$PROJECT_DIR/setup-yocto-env.sh"

# Build the target
cd "$PROJECT_DIR/build"
bitbake $TARGET

echo "Build complete for $TARGET"
EOF
        chmod +x "$PROJECT_DIR/scripts/build.sh"
    fi

    # Create flash.sh
    if [ ! -f "$PROJECT_DIR/scripts/flash.sh" ]; then
        cat > "$PROJECT_DIR/scripts/flash.sh" << 'EOF'
#!/bin/bash

# Flash script for Robotics Controller
# Usage: ./scripts/flash.sh [device]

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

# Default device
DEVICE=${1:-/dev/sdb}

# Validate device
if [ ! -e "$DEVICE" ]; then
    echo "Error: Device $DEVICE does not exist"
    exit 1
fi

# Setup build environment
source "$PROJECT_DIR/setup-yocto-env.sh"

# Change to build directory
cd "$PROJECT_DIR/build"

# Get the latest image
IMAGE=$(find tmp/deploy/images/beaglebone-robotics/ -name "robotics-image-beaglebone-robotics.wic.gz" -type f -exec ls -t {} \; | head -n 1)

if [ -z "$IMAGE" ]; then
    echo "Error: No image found. Run build.sh first."
    exit 1
fi

echo "Found image: $IMAGE"
echo "Flashing to $DEVICE..."

# Confirm before proceeding
read -p "This will erase all data on $DEVICE. Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

# Flash the image
gunzip -c "$IMAGE" | sudo dd of="$DEVICE" bs=4M status=progress conv=fsync

echo "Flash complete!"
EOF
        chmod +x "$PROJECT_DIR/scripts/flash.sh"
    fi

    # Create clean.sh
    if [ ! -f "$PROJECT_DIR/scripts/clean.sh" ]; then
        cat > "$PROJECT_DIR/scripts/clean.sh" << 'EOF'
#!/bin/bash

# Clean script for Robotics Controller
# Usage: ./scripts/clean.sh [option]

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

# Change to build directory
cd "$PROJECT_DIR/build" || exit 1

# Parse options
case "$1" in
    all)
        echo "Cleaning all build artifacts..."
        rm -rf tmp/
        rm -rf sstate-cache/
        rm -rf cache/
        rm -rf downloads/
        ;;
    tmp)
        echo "Cleaning tmp directory..."
        rm -rf tmp/
        ;;
    cache)
        echo "Cleaning cache directories..."
        rm -rf sstate-cache/
        rm -rf cache/
        ;;
    *)
        echo "Usage: $0 {all|tmp|cache}"
        echo "  all    - Clean all build artifacts"
        echo "  tmp    - Clean only tmp directory"
        echo "  cache  - Clean cache directories"
        exit 1
        ;;
esac

echo "Clean complete!"
EOF
        chmod +x "$PROJECT_DIR/scripts/clean.sh"
    fi

    # Create run.sh (QEMU simulator)
    if [ ! -f "$PROJECT_DIR/scripts/run.sh" ]; then
        cat > "$PROJECT_DIR/scripts/run.sh" << 'EOF'
#!/bin/bash

# Run script for Robotics Controller in QEMU
# Usage: ./scripts/run.sh

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

# Setup build environment
source "$PROJECT_DIR/setup-yocto-env.sh"

# Change to build directory
cd "$PROJECT_DIR/build" || exit 1

# Get the latest image
KERNEL=$(find tmp/deploy/images/qemuarm/ -name "zImage" -type f -exec ls -t {} \; | head -n 1)
ROOTFS=$(find tmp/deploy/images/qemuarm/ -name "robotics-image-qemuarm.ext4" -type f -exec ls -t {} \; | head -n 1)

if [ -z "$KERNEL" ] || [ -z "$ROOTFS" ]; then
    echo "Error: Kernel or rootfs not found. Run build.sh with qemuarm target first."
    exit 1
fi

echo "Running QEMU with:"
echo "Kernel: $KERNEL"
echo "Rootfs: $ROOTFS"

# Run QEMU
runqemu qemuarm

echo "QEMU session ended"
EOF
        chmod +x "$PROJECT_DIR/scripts/run.sh"
    fi

    # Create save-config.sh
    if [ ! -f "$PROJECT_DIR/scripts/save-config.sh" ]; then
        cat > "$PROJECT_DIR/scripts/save-config.sh" << 'EOF'
#!/bin/bash

# Save current configuration
# Usage: ./scripts/save-config.sh [name]

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

# Default config name
CONFIG_NAME=${1:-default}
CONFIG_DIR="$PROJECT_DIR/build/saved-configs/$CONFIG_NAME"

# Setup build environment
source "$PROJECT_DIR/setup-yocto-env.sh"

# Create config directory
mkdir -p "$CONFIG_DIR"

# Copy configuration files
cp "$PROJECT_DIR/build/conf/local.conf" "$CONFIG_DIR/"
cp "$PROJECT_DIR/build/conf/bblayers.conf" "$CONFIG_DIR/"

echo "Configuration saved to $CONFIG_DIR"
EOF
        chmod +x "$PROJECT_DIR/scripts/save-config.sh"
    fi

    # Create change-machine.sh
    if [ ! -f "$PROJECT_DIR/scripts/change-machine.sh" ]; then
        cat > "$PROJECT_DIR/scripts/change-machine.sh" << 'EOF'
#!/bin/bash

# Change machine target
# Usage: ./scripts/change-machine.sh <machine>

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

# Validate machine name
if [ -z "$1" ]; then
    echo "Usage: $0 <machine>"
    echo "Available machines:"
    find "$PROJECT_DIR/meta-robotics/conf/machine" -name "*.conf" -exec basename {} .conf \;
    exit 1
fi

MACHINE=$1

# Check if machine config exists
if [ ! -f "$PROJECT_DIR/meta-robotics/conf/machine/$MACHINE.conf" ]; then
    echo "Error: Machine $MACHINE not found"
    echo "Available machines:"
    find "$PROJECT_DIR/meta-robotics/conf/machine" -name "*.conf" -exec basename {} .conf \;
    exit 1
fi

# Setup build environment
source "$PROJECT_DIR/setup-yocto-env.sh"

# Change to build directory
cd "$PROJECT_DIR/build" || exit 1

# Update local.conf
sed -i "s/^MACHINE.*$/MACHINE ?= \"$MACHINE\"/" "$PROJECT_DIR/build/conf/local.conf"

echo "Machine target changed to $MACHINE"
EOF
        chmod +x "$PROJECT_DIR/scripts/change-machine.sh"
    fi

    # Create README.md for scripts directory
    if [ ! -f "$PROJECT_DIR/scripts/README.md" ]; then
        cat > "$PROJECT_DIR/scripts/README.md" << 'EOF'
# Robotics Controller Utility Scripts

This directory contains utility scripts for building, flashing, and managing the Robotics Controller.

## Scripts

- **build.sh** - Build the Yocto project (default target: robotics-image)
- **flash.sh** - Flash the built image to an SD card or eMMC
- **clean.sh** - Clean build artifacts
- **run.sh** - Run the image in QEMU for testing
- **save-config.sh** - Save the current build configuration
- **change-machine.sh** - Change the target machine

## Usage Examples

Build the default image:
```
./scripts/build.sh
```

Build a specific target:
```
./scripts/build.sh robotics-image-dev
```

Flash to an SD card:
```
./scripts/flash.sh /dev/sdX
```

Clean all build artifacts:
```
./scripts/clean.sh all
```

Run in QEMU:
```
./scripts/run.sh
```

Save the current configuration:
```
./scripts/save-config.sh my-custom-config
```

Change target machine:
```
./scripts/change-machine.sh rpi4
```
EOF
    fi

    echo -e "${GREEN}Tools and scripts framework created successfully!${NC}"
}

# Function to check for necessary tools
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"

    MISSING_TOOLS=""

    # Check for necessary tools
    for tool in git make gcc g++ python3 chrpath diffstat gawk wget; do
        if ! command -v $tool &> /dev/null; then
            MISSING_TOOLS="$MISSING_TOOLS $tool"
        fi
    done

    # If there are missing tools, print a message and exit
    if [ -n "$MISSING_TOOLS" ]; then
        echo -e "${RED}The following tools are missing:${NC}$MISSING_TOOLS"
        echo -e "${YELLOW}Please install these tools and run the script again.${NC}"
        echo -e "On Ubuntu/Debian: sudo apt-get update && sudo apt-get install$MISSING_TOOLS"
        return 1
    fi

    echo -e "${GREEN}All prerequisites are met.${NC}"
    return 0
}

# Function to create codebase structure
create_codebase_structure() {
    echo -e "${BLUE}Creating codebase directory structure...${NC}"

    # Create main directories
    mkdir -p "$PROJECT_DIR/src/robotics-controller"
    mkdir -p "$PROJECT_DIR/src/config"
    mkdir -p "$PROJECT_DIR/src/scripts"
    mkdir -p "$PROJECT_DIR/src/web-interface"

    # Create documentation directories
    mkdir -p "$PROJECT_DIR/docs"

    # Create test directories
    mkdir -p "$PROJECT_DIR/tests"

    # Create scripts directory
    mkdir -p "$PROJECT_DIR/scripts"

    # Create basic README files
    if [ ! -f "$PROJECT_DIR/src/robotics-controller/README.md" ]; then
        echo "# Robotics Controller" > "$PROJECT_DIR/src/robotics-controller/README.md"
        echo "Main application code for the robotics controller." >> "$PROJECT_DIR/src/robotics-controller/README.md"
    fi

    if [ ! -f "$PROJECT_DIR/src/web-interface/README.md" ]; then
        echo "# Web Interface" > "$PROJECT_DIR/src/web-interface/README.md"
        echo "Web-based user interface for the robotics controller." >> "$PROJECT_DIR/src/web-interface/README.md"
    fi

    if [ ! -f "$PROJECT_DIR/scripts/README.md" ]; then
        echo "# Utility Scripts" > "$PROJECT_DIR/scripts/README.md"
        echo "Scripts for building, flashing, and managing the robotics controller." >> "$PROJECT_DIR/scripts/README.md"
    fi

    echo -e "${GREEN}Codebase structure created successfully!${NC}"
}

# Main script execution

# Check prerequisites first
check_prerequisites || exit 1

# Check for -y flag for non-interactive mode
INTERACTIVE=true
if [ "$1" == "-y" ]; then
    INTERACTIVE=false
fi

# Check if directories exist and offer to create the structure
if [ ! -d "$PROJECT_DIR/src" ]; then
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${YELLOW}Codebase structure not found. Do you want to create it now?${NC}"
        read -p "Create codebase structure? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            create_codebase_structure
        else
            echo -e "${YELLOW}Skipping codebase structure creation.${NC}"
        fi
    else
        create_codebase_structure
    fi
else
    echo -e "${BLUE}Codebase structure already exists.${NC}"
fi

# Check if git repo is initialized
if [ ! -d "$PROJECT_DIR/.git" ]; then
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${YELLOW}Git repository not initialized. Do you want to initialize it now?${NC}"
        read -p "Initialize git repository? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            initialize_git_repo
        else
            echo -e "${YELLOW}Skipping git repository initialization.${NC}"
        fi
    else
        initialize_git_repo
    fi
else
    echo -e "${BLUE}Git repository already initialized.${NC}"
fi

# Check if meta-robotics layer exists
if [ ! -d "$PROJECT_DIR/meta-robotics" ]; then
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${YELLOW}meta-robotics layer not found. Do you want to create it now?${NC}"
        read -p "Create meta-robotics layer? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            create_meta_layer
        else
            echo -e "${YELLOW}Skipping meta-robotics layer creation.${NC}"
        fi
    else
        create_meta_layer
    fi
else
    echo -e "${BLUE}meta-robotics layer already exists.${NC}"
fi

# Check if buildroot external layer exists
if [ ! -d "$PROJECT_DIR/build/buildroot-external" ]; then
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${YELLOW}Buildroot external layer not found. Do you want to create it now?${NC}"
        read -p "Create Buildroot external layer? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            create_buildroot_external
        else
            echo -e "${YELLOW}Skipping Buildroot external layer creation.${NC}"
        fi
    else
        create_buildroot_external
    fi
else
    echo -e "${BLUE}Buildroot external layer already exists.${NC}"
fi

# Check if scripts framework exists
if [ ! -f "$PROJECT_DIR/scripts/build.sh" ]; then
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${YELLOW}Tools and scripts framework not found. Do you want to create it now?${NC}"
        read -p "Create tools and scripts framework? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            create_tools_framework
        else
            echo -e "${YELLOW}Skipping tools and scripts framework creation.${NC}"
        fi
    else
        create_tools_framework
    fi
else
    echo -e "${BLUE}Tools and scripts framework already exists.${NC}"
fi

# Check if Poky is cloned
if [ ! -d "$PROJECT_DIR/build/poky" ]; then
    echo -e "${YELLOW}Poky is not yet cloned. Do you want to clone it now?${NC}"
    echo -e "This is required for Yocto builds."
    read -p "Clone Poky? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "${BLUE}Cloning Poky (Yocto Project reference distribution)...${NC}"
        mkdir -p "$PROJECT_DIR/build"
        git clone git://git.yoctoproject.org/poky -b scarthgap "$PROJECT_DIR/build/poky"
        echo -e "${GREEN}Poky cloned successfully!${NC}"
    else
        echo -e "${YELLOW}Skipping Poky clone. You will need to clone it manually.${NC}"
    fi
fi

# Check if meta-openembedded is cloned
if [ ! -d "$PROJECT_DIR/build/meta-openembedded" ]; then
    echo -e "${YELLOW}meta-openembedded is not yet cloned. Do you want to clone it now?${NC}"
    echo -e "This is required for many packages in the robotics image."
    read -p "Clone meta-openembedded? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "${BLUE}Cloning meta-openembedded layer...${NC}"
        git clone git://git.openembedded.org/meta-openembedded -b scarthgap "$PROJECT_DIR/build/meta-openembedded"
        echo -e "${GREEN}meta-openembedded cloned successfully!${NC}"
    else
        echo -e "${YELLOW}Skipping meta-openembedded clone. You will need to clone it manually.${NC}"
    fi
fi

# Function to add a meta-layer to bblayers.conf
add_layer_to_bblayers() {
    local layer_name="$1"
    local layer_path="$2"

    if [ -f "$PROJECT_DIR/build/conf/bblayers.conf" ]; then
        if ! grep -q "$layer_name" "$PROJECT_DIR/build/conf/bblayers.conf"; then
            echo -e "${BLUE}Adding $layer_name to bblayers.conf...${NC}"
            # Insert before the last line with meta-robotics
            sed -i "/meta-robotics/i\\  $layer_path \\\\" "$PROJECT_DIR/build/conf/bblayers.conf"
            echo -e "${GREEN}$layer_name added to bblayers.conf${NC}"
        else
            echo -e "${YELLOW}$layer_name already in bblayers.conf${NC}"
        fi
    fi
}

# Function to clone and setup optional meta-layers
setup_optional_layers() {
    echo -e "${BLUE}Setting up optional meta-layers...${NC}"
    echo -e "This will prompt you for each optional layer."
    echo

    # Define available optional layers
    declare -A OPTIONAL_LAYERS=(
        ["meta-raspberrypi"]="git://git.yoctoproject.org/meta-raspberrypi|Raspberry Pi BSP layer"
        ["meta-ti"]="git://git.yoctoproject.org/meta-ti|Texas Instruments BSP layer"
        ["meta-realtime"]="git://git.yoctoproject.org/meta-realtime|Real-time kernel support"
        ["meta-security"]="git://git.yoctoproject.org/meta-security|Security features and hardening"
        ["meta-virtualization"]="git://git.yoctoproject.org/meta-virtualization|Docker and virtualization support"
        ["meta-nodejs"]="git://github.com/imyller/meta-nodejs|Node.js support"
        ["meta-python"]="git://git.openembedded.org/meta-python|Additional Python packages"
        ["meta-multimedia"]="git://git.openembedded.org/meta-multimedia|Multimedia packages"
        ["meta-networking"]="git://git.openembedded.org/meta-networking|Networking packages"
    )

    for layer in "${!OPTIONAL_LAYERS[@]}"; do
        IFS='|' read -r repo description <<< "${OPTIONAL_LAYERS[$layer]}"

        if [ ! -d "$PROJECT_DIR/build/$layer" ]; then
            echo -e "${YELLOW}$layer is not cloned.${NC}"
            echo -e "Description: $description"
            read -p "Clone $layer? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}Cloning $layer...${NC}"
                if git clone "$repo" -b scarthgap "$PROJECT_DIR/build/$layer"; then
                    echo -e "${GREEN}$layer cloned successfully!${NC}"
                    add_layer_to_bblayers "$layer" "\${TOPDIR}/../$layer"
                else
                    echo -e "${RED}Failed to clone $layer${NC}"
                fi
            fi
        else
            echo -e "${GREEN}$layer already exists${NC}"
            add_layer_to_bblayers "$layer" "\${TOPDIR}/../$layer"
        fi
        echo
    done
}

# Check if meta-raspberrypi is cloned (only needed for Raspberry Pi builds)
if [ ! -d "$PROJECT_DIR/build/meta-raspberrypi" ]; then
    echo -e "${YELLOW}meta-raspberrypi is not yet cloned. Do you want to clone it now?${NC}"
    echo -e "This is only required if you want to build for Raspberry Pi targets."
    read -p "Clone meta-raspberrypi? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "${BLUE}Cloning meta-raspberrypi layer...${NC}"
        git clone git://git.yoctoproject.org/meta-raspberrypi -b scarthgap "$PROJECT_DIR/build/meta-raspberrypi"
        echo -e "${GREEN}meta-raspberrypi cloned successfully!${NC}"
        add_layer_to_bblayers "meta-raspberrypi" "\${TOPDIR}/../meta-raspberrypi"
    else
        echo -e "${YELLOW}Skipping meta-raspberrypi clone. You will need to clone it manually if building for Raspberry Pi.${NC}"
    fi
else
    add_layer_to_bblayers "meta-raspberrypi" "\${TOPDIR}/../meta-raspberrypi"
fi

# Ask if user wants to setup additional optional layers
echo
echo -e "${YELLOW}Would you like to setup additional meta-layers?${NC}"
echo -e "Available layers include: meta-ti, meta-realtime, meta-security, meta-virtualization, etc."
read -p "Setup optional layers? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    setup_optional_layers
fi

# Source Poky environment if it exists
if [ -d "$PROJECT_DIR/build/poky" ]; then
    echo -e "${BLUE}Initializing Yocto build environment...${NC}"
    source "$PROJECT_DIR/build/poky/oe-init-build-env" "$PROJECT_DIR/build"

    # Add our layer if not already in bblayers.conf
    if [ -f "$PROJECT_DIR/build/conf/bblayers.conf" ]; then
        if ! grep -q "meta-robotics" "$PROJECT_DIR/build/conf/bblayers.conf"; then
            echo -e "${BLUE}Adding meta-robotics layer to build configuration...${NC}"
            # Backup the original file
            cp "$PROJECT_DIR/build/conf/bblayers.conf" "$PROJECT_DIR/build/conf/bblayers.conf.bak"
            # Add our layer using a simpler approach
            sed -i "/^\s*\"$/i\\  $PROJECT_DIR/meta-robotics \\\\" "$PROJECT_DIR/build/conf/bblayers.conf"
        else
            echo -e "${BLUE}meta-robotics layer already in bblayers.conf${NC}"
        fi
    else
        echo -e "${YELLOW}bblayers.conf does not exist yet. It will be created by the Yocto initialization process.${NC}"
    fi

    # Set machine if not already set
    if [ -f "$PROJECT_DIR/build/conf/local.conf" ]; then
        if ! grep -q '^MACHINE' "$PROJECT_DIR/build/conf/local.conf"; then
            echo -e "${BLUE}Setting default machine to beaglebone-robotics...${NC}"
            echo 'MACHINE ?= "beaglebone-robotics"' >> "$PROJECT_DIR/build/conf/local.conf"
        else
            echo -e "${BLUE}Machine already configured in local.conf${NC}"
        fi
    else
        echo -e "${YELLOW}local.conf does not exist yet. It will be created by the Yocto initialization process.${NC}"
    fi

    echo -e "${GREEN}Yocto build environment initialized!${NC}"
    echo -e "${YELLOW}You can now run:${NC} bitbake robotics-image"
    echo -e "${YELLOW}To add more layers later, run:${NC} add_meta_layer <layer-name> <git-url>"
else
    echo -e "${RED}Poky not found. Please clone it first by running:${NC}"
    echo -e "${YELLOW}./scripts/build.sh${NC}"
fi

# Function to add a new meta-layer (for use after initial setup)
add_meta_layer() {
    if [ $# -lt 2 ]; then
        echo "Usage: add_meta_layer <layer-name> <git-url> [branch]"
        echo "Example: add_meta_layer meta-golang https://github.com/bmwcarit/meta-golang scarthgap"
        return 1
    fi

    local layer_name="$1"
    local git_url="$2"
    local branch="${3:-scarthgap}"
    local layer_path="$PROJECT_DIR/build/$layer_name"

    echo -e "${BLUE}Adding new meta-layer: $layer_name${NC}"

    # Clone the layer if it doesn't exist
    if [ ! -d "$layer_path" ]; then
        echo -e "${BLUE}Cloning $layer_name from $git_url...${NC}"
        if git clone "$git_url" -b "$branch" "$layer_path"; then
            echo -e "${GREEN}$layer_name cloned successfully!${NC}"
        else
            echo -e "${RED}Failed to clone $layer_name${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}$layer_name already exists at $layer_path${NC}"
    fi

    # Add to bblayers.conf
    add_layer_to_bblayers "$layer_name" "\${TOPDIR}/../$layer_name"

    echo -e "${GREEN}$layer_name has been added to your Yocto build!${NC}"
    echo -e "${YELLOW}Note: You may need to check layer dependencies and update local.conf if needed.${NC}"
}

# Function to list available layers
list_available_layers() {
    echo -e "${BLUE}Popular meta-layers for embedded/robotics development:${NC}"
    echo
    echo -e "${YELLOW}Hardware BSP Layers:${NC}"
    echo "  meta-ti               - Texas Instruments (BeagleBone, etc.)"
    echo "  meta-raspberrypi      - Raspberry Pi support"
    echo "  meta-intel            - Intel hardware support"
    echo "  meta-xilinx           - Xilinx FPGA/SoC support"
    echo
    echo -e "${YELLOW}Real-time and Performance:${NC}"
    echo "  meta-realtime         - Real-time kernel patches"
    echo "  meta-latency-testing  - Latency testing tools"
    echo
    echo -e "${YELLOW}Security:${NC}"
    echo "  meta-security         - Security hardening features"
    echo "  meta-tpm              - TPM support"
    echo "  meta-selinux          - SELinux support"
    echo
    echo -e "${YELLOW}Connectivity and IoT:${NC}"
    echo "  meta-networking       - Additional networking packages"
    echo "  meta-bluetooth        - Bluetooth stack"
    echo "  meta-wifi             - WiFi support"
    echo "  meta-iot              - IoT frameworks"
    echo
    echo -e "${YELLOW}Development and Languages:${NC}"
    echo "  meta-nodejs           - Node.js support"
    echo "  meta-python           - Extended Python packages"
    echo "  meta-rust             - Rust programming language"
    echo "  meta-golang           - Go programming language"
    echo "  meta-java             - Java support"
    echo
    echo -e "${YELLOW}Robotics and AI:${NC}"
    echo "  meta-ros              - Robot Operating System"
    echo "  meta-tensorflow-lite  - TensorFlow Lite"
    echo "  meta-opencv           - OpenCV computer vision"
    echo "  meta-ml               - Machine learning frameworks"
    echo
    echo -e "${YELLOW}Multimedia and Graphics:${NC}"
    echo "  meta-multimedia       - Audio/video packages"
    echo "  meta-qt5              - Qt5 framework"
    echo "  meta-gnome            - GNOME desktop"
    echo
    echo -e "${YELLOW}Virtualization and Containers:${NC}"
    echo "  meta-virtualization   - Docker, LXC, etc."
    echo "  meta-cloud-services   - Cloud service integration"
    echo
    echo -e "${BLUE}To add a layer, use:${NC} add_meta_layer <layer-name> <git-url>"
}

# Export functions for use in shell
export -f add_meta_layer
export -f list_available_layers
