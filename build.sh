#!/bin/bash

# Set project root and build directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

# Simple Yocto build script with machine and image selection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# =====================
# Function Definitions
# =====================

usage() {
    cat << EOF
Usage: $0 [-m MACHINE] [-i IMAGE]

Simple Yocto build script with machine and image selection.

OPTIONS:
  -m MACHINE   Target machine (e.g. qemuarm64, beaglebone-robotics, raspberrypi3, etc.)
  -i IMAGE     Image or recipe to build (e.g. core-image-minimal, robotics-controller, etc.)
  -h, --help   Show this help message

EXAMPLES:
  $0 -m qemuarm64 -i core-image-minimal
  $0 -m beaglebone-robotics -i robotics-controller-image
  $0 -m qemu-robotics -i robotics-controller
EOF
    exit 1
}

parse_args() {
    MACHINE=""
    IMAGE=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--machine)
                MACHINE="$2"
                shift 2
                ;;
            -i|--image)
                IMAGE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Prompt for machine if not provided
    if [ -z "$MACHINE" ]; then
        log_warn "No machine specified. Please enter the Yocto MACHINE (e.g. qemuarm64, beaglebone-robotics, raspberrypi3, etc.):"
        read -r MACHINE
        if [ -z "$MACHINE" ]; then
            log_error "MACHINE is required."
            exit 1
        fi
    fi

    # Prompt for image if not provided
    if [ -z "$IMAGE" ]; then
        log_warn "No image or recipe specified. Please enter the Yocto IMAGE or RECIPE to build (e.g. core-image-minimal, robotics-controller, etc.):"
        read -r IMAGE
        if [ -z "$IMAGE" ]; then
            log_error "IMAGE or RECIPE is required."
            exit 1
        fi
    fi

    log_info "Selected MACHINE: $MACHINE"
    log_info "Selected IMAGE/RECIPE: $IMAGE"
}

init_submodules() {
    log_info "Initializing and updating git submodules..."
    cd "$PROJECT_ROOT"
    git submodule init
    git submodule sync
    git submodule update --recursive
}

check_poky() {
    if [ ! -d "$PROJECT_ROOT/poky" ] || [ ! -d "${PROJECT_ROOT}/meta-openembedded" ]; then
        log_error "poky or meta-openembedded directory not found. Ensure submodules are initialized."
        exit 1
    fi
}

source_yocto_env() {
    log_info "Sourcing Yocto environment..."
    cd "$PROJECT_ROOT"

    # Source the Yocto environment (this will change directory to build/)
    source poky/oe-init-build-env "$BUILD_DIR"

    # Verify we're in the build directory
    if [ "$(pwd)" != "$BUILD_DIR" ]; then
        log_error "Failed to change to build directory after sourcing environment"
        exit 1
    fi
}

copy_templates() {
    case "$MACHINE" in
        qemu-robotics)
            TEMPLATE_DIR="$PROJECT_ROOT/meta-robotics/conf/templates/qemu-config";;
        rpi3-robotics)
            TEMPLATE_DIR="$PROJECT_ROOT/meta-robotics/conf/templates/rpi3-config";;
        rpi4-robotics)
            TEMPLATE_DIR="$PROJECT_ROOT/meta-robotics/conf/templates/rpi4-config";;
        beaglebone-robotics)
            TEMPLATE_DIR="$PROJECT_ROOT/meta-robotics/conf/templates/beaglebone-config";;
        *)
            TEMPLATE_DIR="$PROJECT_ROOT/meta-robotics/conf/templates";;
    esac

    if [ -d "$TEMPLATE_DIR" ]; then
        if [ -f "$TEMPLATE_DIR/local.conf" ]; then
            log_info "Copying local.conf from $TEMPLATE_DIR"
            cp "$TEMPLATE_DIR/local.conf" "$BUILD_DIR/conf/local.conf"
        fi
        if [ -f "$TEMPLATE_DIR/bblayers.conf" ]; then
            log_info "Copying bblayers.conf from $TEMPLATE_DIR"
            cp "$TEMPLATE_DIR/bblayers.conf" "$BUILD_DIR/conf/bblayers.conf"
        fi
    else
        log_warn "No template directory found for $MACHINE. Skipping template copy."
    fi
}

ensure_machine_in_localconf() {
    CONFLINE="MACHINE = \"$MACHINE\""
    if [ ! -f "$BUILD_DIR/conf/local.conf" ]; then
        log_error "conf/local.conf not found. Ensure your Yocto environment is set up."
        exit 1
    fi

    # Remove any existing MACHINE line and add the new one
    grep -v "^MACHINE\s*=" "$BUILD_DIR/conf/local.conf" > "$BUILD_DIR/conf/local.conf.tmp"
    echo "$CONFLINE" >> "$BUILD_DIR/conf/local.conf.tmp"
    mv "$BUILD_DIR/conf/local.conf.tmp" "$BUILD_DIR/conf/local.conf"

    log_info "Set MACHINE to $MACHINE in conf/local.conf"
}

add_meta_robotics_layer() {
    log_info "Checking meta-robotics layer..."
    if [ -d "$PROJECT_ROOT/meta-robotics" ]; then
        # Check if layer is already added
        if ! bitbake-layers show-layers | grep -q "meta-robotics"; then
            log_info "Adding meta-robotics layer"
            bitbake-layers add-layer "$PROJECT_ROOT/meta-robotics"
        else
            log_info "meta-robotics layer already exists"
        fi

        # Print summary of image recipes in meta-robotics
        image_recipes=$(find "$PROJECT_ROOT/meta-robotics" -type f -name "*.bb" -path "*/images/*" 2>/dev/null)
        if [ -n "$image_recipes" ]; then
            log_info "Image recipes found in meta-robotics:"
            for recipe in $image_recipes; do
                log_info "  - $(basename "$recipe" .bb)"
            done
        else
            log_info "No image recipes found in meta-robotics."
        fi
    else
        log_warn "meta-robotics layer not found in project root. Skipping layer add and recipe summary."
    fi
}

build_image_or_recipe() {
    log_info "Building image or recipe: $IMAGE"

    # Ensure we're in the build directory
    cd "$BUILD_DIR"

    # Build the image/recipe
    if bitbake "$IMAGE"; then
        log_success "Build complete!"
        log_info "Artifacts are in $BUILD_DIR/tmp/deploy/images/$MACHINE"

        # List the built images
        IMAGE_DIR="$BUILD_DIR/tmp/deploy/images/$MACHINE"
        if [ -d "$IMAGE_DIR" ]; then
            log_info "Built images:"
            ls -la "$IMAGE_DIR"/*.wic* "$IMAGE_DIR"/*.img* "$IMAGE_DIR"/*.rootfs* 2>/dev/null || log_info "No standard image files found"
        fi
    else
        log_error "Build failed!"
        exit 1
    fi
}

# =====================
# Main
# =====================

main() {
    log_info "Starting Yocto build script..."
    log_info "Project root: $PROJECT_ROOT"
    log_info "Build directory: $BUILD_DIR"

    parse_args "$@"
    init_submodules
    check_poky
    source_yocto_env
    copy_templates
    ensure_machine_in_localconf
    add_meta_robotics_layer
    build_image_or_recipe
}

main "$@"
