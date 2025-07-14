#!/bin/bash
# Simplified Dual Environment Script for Robotics Controller
# Author: Siddhant Jajoo
# Description: Manage different build environments

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

# Help function
show_help() {
    cat << EOF
Usage: $0 [ACTION] [TARGET]

Simplified dual environment manager for different build targets.

ACTIONS:
    setup TARGET    Setup build environment for target
    build TARGET    Build image for target  
    clean TARGET    Clean build environment for target
    status          Show status of all environments

TARGETS:
    qemu            QEMU virtual environment
    beaglebone      BeagleBone Black hardware
    rpi3            Raspberry Pi 3 hardware
    rpi4            Raspberry Pi 4 hardware

EXAMPLES:
    $0 setup qemu           # Setup QEMU environment
    $0 build rpi3           # Build for Raspberry Pi 3
    $0 build rpi4           # Build for Raspberry Pi 4
    $0 clean beaglebone     # Clean BeagleBone environment
    $0 status               # Show all environment status

EOF
}

# Initialize target configurations
init_target_configs() {
    # Available targets and their configurations
    declare -A TARGET_MACHINES
    TARGET_MACHINES[qemu]="qemu-robotics"
    TARGET_MACHINES[beaglebone]="beaglebone-robotics"
    TARGET_MACHINES[rpi3]="rpi3-robotics"
    TARGET_MACHINES[rpi4]="rpi4-robotics"

    declare -A TARGET_IMAGES
    TARGET_IMAGES[qemu]="robotics-qemu-image"
    TARGET_IMAGES[beaglebone]="robotics-controller-image"
    TARGET_IMAGES[rpi3]="robotics-controller-image"
    TARGET_IMAGES[rpi4]="robotics-controller-image"
    
    # Export arrays for use in other functions
    export TARGET_MACHINES TARGET_IMAGES
}

# Validate target
validate_target() {
    local target="$1"
    
    if [ -z "$target" ]; then
        log_error "Target required"
        show_help
        exit 1
    fi
    
    case "$target" in
        qemu|beaglebone|rpi3|rpi4)
            return 0
            ;;
        *)
            log_error "Unknown target: $target"
            log_info "Available targets: qemu, beaglebone, rpi3, rpi4"
            exit 1
            ;;
    esac
}

# Setup environment for target
setup_environment() {
    local target="$1"
    
    log_info "Setting up environment for $target"
    
    local machine=""
    local image=""
    
    case "$target" in
        qemu)
            machine="qemu-robotics"
            image="robotics-qemu-image"
            ;;
        beaglebone)
            machine="beaglebone-robotics" 
            image="robotics-dev-image"
            ;;
        rpi3)
            machine="rpi3-robotics"
            image="robotics-dev-image"
            ;;
        rpi4)
            machine="rpi4-robotics"
            image="robotics-dev-image"
            ;;
    esac
    
    log_info "Machine: $machine"
    log_info "Image: $image"
    
    # Use the build script to setup the environment
    "${PROJECT_ROOT}/scripts/build.sh" "$machine" "$image"
}

# Build for target
build_target() {
    local target="$1"
    
    log_info "Building for $target"
    
    local machine=""
    local image=""
    
    case "$target" in
        qemu)
            machine="qemu-robotics"
            image="robotics-qemu-image"
            ;;
        beaglebone)
            machine="beaglebone-robotics"
            image="robotics-dev-image"
            ;;
        rpi3)
            machine="rpi3-robotics"
            image="robotics-dev-image"
            ;;
        rpi4)
            machine="rpi4-robotics"
            image="robotics-dev-image"
            ;;
    esac
    
    log_info "Machine: $machine"
    log_info "Image: $image"
    
    # Use the build script
    "${PROJECT_ROOT}/scripts/build.sh" "$machine" "$image"
}

# Clean environment for target
clean_target() {
    local target="$1"
    
    log_info "Cleaning environment for $target"
    # Use the clean script
    "${PROJECT_ROOT}/scripts/clean.sh" --build
}

# Show environment status
show_status() {
    log_info "Environment Status:"
    echo "==================="
    
    if [ -d "${PROJECT_ROOT}/build" ]; then
        log_success "Build directory exists"
        
        # Check what machine is configured
        if [ -f "${PROJECT_ROOT}/build/conf/local.conf" ]; then
            local current_machine
            current_machine=$(grep "^MACHINE" "${PROJECT_ROOT}/build/conf/local.conf" 2>/dev/null | cut -d'"' -f2)
            if [ -n "$current_machine" ]; then
                log_info "Current machine: $current_machine"
            else
                log_warn "No machine configured"
            fi
        else
            log_warn "No configuration found"
        fi
        
        # Check for built images
        local deploy_dir="${PROJECT_ROOT}/build/tmp-glibc/deploy/images"
        if [ -d "$deploy_dir" ]; then
            log_info "Available builds:"
            for dir in "$deploy_dir"/*; do
                if [ -d "$dir" ]; then
                    local machine
                    machine=$(basename "$dir")
                    log_info "  - $machine"
                fi
            done
        else
            log_info "No builds found"
        fi
    else
        log_warn "No build directory found"
    fi
    
    if [ -d "${PROJECT_ROOT}/output" ]; then
        log_info "Output directory exists"
    else
        log_warn "No output directory found"
    fi
}

# Main function
main() {
    # Parse arguments
    local action="${1:-status}"
    local target="$2"

    case "$action" in
        -h|--help)
            show_help
            exit 0
            ;;
        setup)
            validate_target "$target"
            setup_environment "$target"
            ;;
        build)
            validate_target "$target"
            build_target "$target"
            ;;
        clean)
            validate_target "$target"
            clean_target "$target"
            ;;
        status)
            show_status
            ;;
        *)
            log_error "Unknown action: $action"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
