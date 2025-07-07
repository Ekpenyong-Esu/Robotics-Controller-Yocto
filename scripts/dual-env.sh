#!/bin/bash

# This script helps manage separate build directories for QEMU and hardware targets
# allowing you to maintain both development environments simultaneously

# Set color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_PATH=$(readlink -f ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname $SCRIPT_PATH)
PROJECT_DIR=$(dirname $SCRIPT_DIR)

# Available targets
targets=("qemu" "beaglebone" "rpi3" "rpi4")
target_names=("QEMU virtual machine" "BeagleBone Black" "Raspberry Pi 3" "Raspberry Pi 4")

# Build directories
declare -A build_dirs
build_dirs[qemu]="build-qemu"
build_dirs[beaglebone]="build-beaglebone"
build_dirs[rpi3]="build-rpi3"
build_dirs[rpi4]="build-rpi4"

# Machine configurations
declare -A machines
machines[qemu]="qemu-robotics"
machines[beaglebone]="beaglebone-robotics"
machines[rpi3]="raspberrypi3"
machines[rpi4]="rpi4-robotics"

# Function to show usage
show_usage() {
    echo -e "${BLUE}Dual Development Environment Manager${NC}\n"
    echo -e "Usage: $0 [OPTION] [TARGET]"
    echo -e "\nOptions:"
    echo -e "  setup TARGET    Create and configure build directory for TARGET"
    echo -e "  build TARGET    Build image for TARGET"
    echo -e "  clean TARGET    Clean build directory for TARGET"
    echo -e "  run             Run QEMU (only for QEMU target)"
    echo -e "  status          Show status of all build environments"
    echo -e "\nTargets:"
    echo -e "  qemu            QEMU virtual machine (for learning/testing)"
    echo -e "  beaglebone      BeagleBone Black (physical hardware)"
    echo -e "  rpi3            Raspberry Pi 3 (physical hardware)"
    echo -e "  rpi4            Raspberry Pi 4 (physical hardware)"
    echo -e "\nExamples:"
    echo -e "  $0 setup qemu           Setup QEMU build environment"
    echo -e "  $0 build beaglebone     Build for BeagleBone Black"
    echo -e "  $0 run                  Run the QEMU virtual machine"
}

# Function to validate target
validate_target() {
    local target=$1
    for valid_target in "${targets[@]}"; do
        if [[ "$target" == "$valid_target" ]]; then
            return 0
        fi
    done
    echo -e "${RED}Error:${NC} Invalid target '$target'"
    echo -e "Valid targets are: ${YELLOW}${targets[*]}${NC}"
    return 1
}

# Function to create and configure build directory
setup_build() {
    local target=$1
    local build_dir=${build_dirs[$target]}
    local machine=${machines[$target]}

    echo -e "${BLUE}Setting up build environment for ${target_names[$target]} (${target})${NC}"

    # Create build directory if it doesn't exist
    if [ ! -d "$PROJECT_DIR/$build_dir" ]; then
        echo -e "${YELLOW}Creating build directory:${NC} $build_dir"
        mkdir -p "$PROJECT_DIR/$build_dir"
    fi

    # Run manage-recipe.sh auto-populate for consistent layer setup
    local manage_recipe_script="$PROJECT_DIR/scripts/manage-recipe.sh"
    if [ -x "$manage_recipe_script" ]; then
        echo -e "${YELLOW}Auto-populating meta-robotics layer...${NC}"
        "$manage_recipe_script" auto-populate --force
        echo -e "${YELLOW}Validating meta-robotics layer...${NC}"
        "$manage_recipe_script" validate
    else
        echo -e "${RED}Warning:${NC} manage-recipe.sh not found, using manual setup"
    fi

    # Sync meta-robotics layer to the specific build directory
    local sync_script="$PROJECT_DIR/scripts/sync-meta-layer.sh"
    if [ -x "$sync_script" ]; then
        echo -e "${YELLOW}Syncing meta-robotics layer to $build_dir...${NC}"
        if ! "$sync_script" sync "$build_dir" --force; then
            echo -e "${RED}Warning:${NC} Failed to sync meta-robotics layer"
        fi
    fi

    # Check for required submodules (poky, meta-openembedded)
    local missing_submodules=()
    if [ ! -d "$PROJECT_DIR/poky" ]; then
        missing_submodules+=("poky")
    fi
    if [ ! -d "$PROJECT_DIR/meta-openembedded" ]; then
        missing_submodules+=("meta-openembedded")
    fi
    if [ ${#missing_submodules[@]} -ne 0 ]; then
        echo -e "${RED}Error:${NC} Required submodules missing: ${missing_submodules[*]}"
        echo -e "Run: ${YELLOW}git submodule update --init --recursive${NC} in the project root."
        return 1
    fi

    echo -e "${YELLOW}Initializing Yocto build environment in:${NC} $build_dir"
    cd "$PROJECT_DIR" || return 1

    # change to the build directory
    source poky/oe-init-build-env "$build_dir"

    # Use machine-specific templates like build.sh does
    setup_machine_templates "$target" "$machine"

    echo -e "${GREEN}Build environment setup complete for:${NC} $target"
    echo -e "You are now in the $build_dir directory."
    echo -e "Run ${YELLOW}bitbake robotics-controller-image${NC} to start building."
}

# Function to setup machine-specific templates (like build.sh)
setup_machine_templates() {
    local target=$1
    local machine=$2

    # Determine machine-specific template directory
    local machine_config_dir=""
    case "$target" in
        "qemu")
            machine_config_dir="qemu-config"
            ;;
        "beaglebone")
            machine_config_dir="beaglebone-config"
            ;;
        "rpi3")
            machine_config_dir="rpi3-config"
            ;;
        "rpi4")
            machine_config_dir="rpi4-config"
            ;;
    esac

    # Setup local.conf with machine-specific template
    setup_local_conf "$machine_config_dir" "$machine"

    # Setup bblayers.conf with machine-specific template
    setup_bblayers_conf "$machine_config_dir" "$target"
}

# Function to setup local.conf with templates
setup_local_conf() {
    local machine_config_dir=$1
    local machine=$2

    if [ -n "$machine_config_dir" ] && [ -f "$PROJECT_DIR/meta-robotics/conf/templates/${machine_config_dir}/local.conf" ]; then
        echo -e "${YELLOW}Using machine-specific local.conf template:${NC} ${machine_config_dir}/local.conf"
        cp "$PROJECT_DIR/meta-robotics/conf/templates/${machine_config_dir}/local.conf" "$PWD/conf/local.conf"
    elif [ -f "$PROJECT_DIR/meta-robotics/conf/templates/local.conf" ]; then
        echo -e "${YELLOW}Using generic local.conf template${NC}"
        cp "$PROJECT_DIR/meta-robotics/conf/templates/local.conf" "$PWD/conf/local.conf"
        # Update machine in the generic template
        if grep -q "^MACHINE ?=" "$PWD/conf/local.conf"; then
            sed -i "s/^MACHINE ?=.*$/MACHINE ?= \"$machine\"/" "$PWD/conf/local.conf"
        else
            echo "MACHINE ?= \"$machine\"" >> "$PWD/conf/local.conf"
        fi
    else
        echo -e "${YELLOW}No template found, configuring machine manually${NC}"
        # Fallback to manual configuration
        if [ -f "$PWD/conf/local.conf" ]; then
            if grep -q "^MACHINE ?=" "$PWD/conf/local.conf"; then
                sed -i "s/^MACHINE ?=.*$/MACHINE ?= \"$machine\"/" "$PWD/conf/local.conf"
            else
                echo "MACHINE ?= \"$machine\"" >> "$PWD/conf/local.conf"
            fi
        fi
    fi
}

# Function to setup bblayers.conf with templates
setup_bblayers_conf() {
    local machine_config_dir=$1
    local target=$2

    if [ -n "$machine_config_dir" ] && [ -f "$PROJECT_DIR/meta-robotics/conf/templates/${machine_config_dir}/bblayers.conf" ]; then
        echo -e "${YELLOW}Using machine-specific bblayers.conf template:${NC} ${machine_config_dir}/bblayers.conf"
        cp "$PROJECT_DIR/meta-robotics/conf/templates/${machine_config_dir}/bblayers.conf" "$PWD/conf/bblayers.conf"
    elif [ -f "$PROJECT_DIR/meta-robotics/conf/templates/bblayers.conf" ]; then
        echo -e "${YELLOW}Using generic bblayers.conf template${NC}"
        cp "$PROJECT_DIR/meta-robotics/conf/templates/bblayers.conf" "$PWD/conf/bblayers.conf"
    else
        echo -e "${YELLOW}No bblayers template found, using manual layer setup${NC}"
        # Fallback to manual layer addition (existing logic)
        manual_layer_setup "$target"
    fi
}

# Function for manual layer setup (fallback)
manual_layer_setup() {
    local target=$1

    # Add meta-robotics layer if not already in bblayers.conf
    if [ -f "$PWD/conf/bblayers.conf" ]; then
        if ! grep -q "meta-robotics" "$PWD/conf/bblayers.conf"; then
            echo -e "${YELLOW}Adding meta-robotics layer to build configuration...${NC}"
            # Add our layer by inserting before the closing quote (" on its own line)
            sed -i '/^[[:space:]]*"[[:space:]]*$/i\  \${TOPDIR}/../meta-robotics \\' "$PWD/conf/bblayers.conf"
        fi
    fi

    # Add meta-raspberrypi layer for RPi targets
    if [[ "$target" == "rpi3" || "$target" == "rpi4" ]] && [ -f "$PWD/conf/bblayers.conf" ]; then
        if ! grep -q "meta-raspberrypi" "$PWD/conf/bblayers.conf"; then
            echo -e "${YELLOW}Adding meta-raspberrypi layer for Raspberry Pi support...${NC}"
            if [ -d "$PROJECT_DIR/meta-raspberrypi" ]; then
                sed -i "/meta-robotics/i\\  \\${TOPDIR}/../meta-raspberrypi \\\\" "$PWD/conf/bblayers.conf"
            else
                echo -e "${RED}Warning:${NC} meta-raspberrypi layer not found."
                echo -e "Run './scripts/build.sh' first to set up repositories."
            fi
        fi
    fi
}

# Function to build image for target
build_image() {
    local target=$1
    local build_dir=${build_dirs[$target]}

    # Check if build directory exists
    if [ ! -d "$PROJECT_DIR/$build_dir" ]; then
        echo -e "${RED}Error:${NC} Build directory not found: $build_dir"
        echo -e "Run '$0 setup $target' first to set up the build environment."
        return 1
    fi

    echo -e "${BLUE}Building image for ${target_names[$target]} (${target})${NC}"
    cd "$PROJECT_DIR"
    source poky/oe-init-build-env "$build_dir"

    echo -e "${YELLOW}Starting build...${NC}"
    bitbake robotics-controller-image

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Build successful!${NC}"
        echo -e "Image is available in: ${YELLOW}$PWD/tmp/deploy/images/${machines[$target]}/${NC}"
    else
        echo -e "${RED}Build failed.${NC} Check the logs for details."
        return 1
    fi
}

# Function to clean build directory
clean_build() {
    local target=$1
    local build_dir=${build_dirs[$target]}

    # Check if build directory exists
    if [ ! -d "$PROJECT_DIR/$build_dir" ]; then
        echo -e "${RED}Error:${NC} Build directory not found: $build_dir"
        return 1
    fi

    echo -e "${BLUE}Cleaning build directory for ${target_names[$target]} (${target})${NC}"
    cd "$PROJECT_DIR"
    source poky/oe-init-build-env "$build_dir"

    echo -e "${YELLOW}Cleaning sstate-cache and tmp directories...${NC}"
    rm -rf "$PWD/tmp" "$PWD/sstate-cache"

    echo -e "${GREEN}Build environment cleaned for:${NC} $target"
}

# Function to run QEMU
run_qemu() {
    local build_dir=${build_dirs[qemu]}

    # Check if build directory exists
    if [ ! -d "$PROJECT_DIR/$build_dir" ]; then
        echo -e "${RED}Error:${NC} QEMU build directory not found: $build_dir"
        echo -e "Run '$0 setup qemu' first to set up the build environment."
        return 1
    fi

    echo -e "${BLUE}Running QEMU virtual machine${NC}"
    cd "$PROJECT_DIR"
    source poky/oe-init-build-env "$build_dir"

    echo -e "${YELLOW}Starting QEMU...${NC}"
    echo -e "Press Ctrl+A, X to exit QEMU"
    runqemu qemux86-64 nographic slirp
}

# Function to show status of all environments
show_status() {
    echo -e "${BLUE}Build Environment Status${NC}\n"

    printf "%-15s %-25s %-10s\n" "TARGET" "DIRECTORY" "STATUS"
    printf "%-15s %-25s %-10s\n" "------" "---------" "------"

    for target in "${targets[@]}"; do
        local build_dir=${build_dirs[$target]}
        local status="Not created"

        if [ -d "$PROJECT_DIR/$build_dir" ]; then
            if [ -f "$PROJECT_DIR/$build_dir/conf/local.conf" ]; then
                status="${GREEN}Ready${NC}"

                # Check for built images
                if [ -d "$PROJECT_DIR/$build_dir/tmp/deploy/images/${machines[$target]}" ]; then
                    if ls "$PROJECT_DIR/$build_dir/tmp/deploy/images/${machines[$target]}"/*rootfs* >/dev/null 2>&1; then
                        status="${GREEN}Built${NC}"
                    fi
                fi
            else
                status="${YELLOW}Incomplete${NC}"
            fi
        fi

        printf "%-15s %-25s %-10s\n" "$target" "$build_dir" "$status"
    done

    echo -e "\nTo set up an environment: $0 setup TARGET"
    echo -e "To build an image: $0 build TARGET"
    echo -e "To run QEMU: $0 run"
}

# Main logic
case "$1" in
    setup)
        if [ -z "$2" ]; then
            echo -e "${RED}Error:${NC} No target specified for setup"
            show_usage
            exit 1
        fi
        validate_target "$2" && setup_build "$2"
        ;;
    build)
        if [ -z "$2" ]; then
            echo -e "${RED}Error:${NC} No target specified for build"
            show_usage
            exit 1
        fi
        validate_target "$2" && build_image "$2"
        ;;
    clean)
        if [ -z "$2" ]; then
            echo -e "${RED}Error:${NC} No target specified for clean"
            show_usage
            exit 1
        fi
        validate_target "$2" && clean_build "$2"
        ;;
    run)
        run_qemu
        ;;
    status)
        show_status
        ;;
    *)
        show_usage
        ;;
esac
