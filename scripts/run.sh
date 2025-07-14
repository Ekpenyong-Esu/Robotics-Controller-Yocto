#!/bin/bash
# Simplified Run Script for Robotics Controller
# Author: Siddhant Jajoo
# Description: Run QEMU image for testing

set -e


# Save the original script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
DEFAULT_MACHINE="qemu-robotics"
DEFAULT_IMAGE="robotics-qemu-image"

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

show_help() {
    cat << EOF
Usage: $0 [MACHINE] [IMAGE]

Simplified run script for robotics controller.

ARGUMENTS:
    MACHINE     Target machine (optional, default: ${DEFAULT_MACHINE})
    IMAGE       Image to run (optional, default: ${DEFAULT_IMAGE})

EXAMPLES:
    $0                              # Run default (qemu-robotics, robotics-qemu-image)
    $0 qemu-robotics                # Run QEMU robotics with default image
    $0 qemu-robotics robotics-qemu-image   # Explicit machine and image

SUPPORTED MACHINES:
    qemu-robotics

NOTE: Only QEMU machines are supported in simplified mode.
For hardware connections, use the original complex scripts.

EOF
}

# Function to validate machine
validate_machine() {
    local machine="$1"

    if [[ ! "$machine" == qemu* ]]; then
        log_error "Simplified run script only supports QEMU machines"
        log_info "Supported: qemu-robotics"
        log_info "For hardware connections, use the full scripts"
        exit 1
    fi
}

# Function to check environment
check_environment() {
    if [ ! -f "$PROJECT_ROOT/poky/oe-init-build-env" ]; then
        log_error "Yocto environment not found. Please run build script first."
        exit 1
    fi
}


# Function to setup environment and ensure we are in the build directory
setup_environment() {
    log_info "Setting up Yocto environment..."
    cd "$PROJECT_ROOT" || exit 1
    # Sourcing this will cd into build/
    source poky/oe-init-build-env
    # Now we are in $PROJECT_ROOT/build
}

# Function to show login instructions
show_login_instructions() {
    log_info "Launching QEMU with SLIRP networking..."
    log_info "Login credentials:"
    log_info "  Username: root"
    log_info "  Password: robotics2025 (or try empty password)"
    log_info ""
    log_info "Network access:"
    log_info "  SSH: ssh root@localhost -p 10022"
    log_info "  Web Interface: http://localhost:8080"
    log_info ""
    log_info "To exit QEMU: Press Ctrl+A, then X"
    log_info ""
}

# Function to run QEMU

run_qemu() {
    local machine="$1"
    local image="$2"

    show_login_instructions

    # Set up SLIRP networking with port forwarding
    export QB_SLIRP_OPT="-netdev user,id=net0,hostfwd=tcp::10022-:22,hostfwd=tcp::8080-:8080"

    # Check for kernel and rootfs files
    local deploy_dir="$PROJECT_ROOT/build/tmp-glibc/deploy/images/$machine"
    local kernel_file="$deploy_dir/Image"
    local rootfs_file="$deploy_dir/${image}-$machine.ext4"
    local conf_file="$deploy_dir/${image}-$machine.qemuboot.conf"

    if [ ! -f "$kernel_file" ]; then
        log_error "Kernel file not found: $kernel_file"
        exit 1
    fi
    if [ ! -f "$rootfs_file" ]; then
        log_error "Root filesystem not found: $rootfs_file"
        exit 1
    fi
    if [ ! -f "$conf_file" ]; then
        log_warn "QEMU boot config not found: $conf_file (will try to run without it)"
    fi

    # Run from the build directory (should already be here)
    if runqemu "$conf_file" slirp nographic; then
        log_success "QEMU session completed"
    else
        log_error "Failed to start QEMU"
        log_info "Make sure the image is built first:"
        log_info "  ./scripts/build.sh $machine $image"
        exit 1
    fi
}

# Main execution function
main() {
    # Parse arguments
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    local machine="${1:-$DEFAULT_MACHINE}"
    local image="${2:-$DEFAULT_IMAGE}"

    log_info "Starting QEMU with machine: $machine, image: $image"

    validate_machine "$machine"
    check_environment
    setup_environment
    run_qemu "$machine" "$image"
}

# Run main function
main "$@"
