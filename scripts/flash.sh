#!/bin/bash
# Simplified Flash Script for Robotics Controller
# Author: Siddhant Jajoo
# Description: Flash image to SD card

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/output"

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
Usage: $0 DEVICE [IMAGE_FILE]

Simplified flash script for robotics controller images.

ARGUMENTS:
    DEVICE      SD card device (e.g., /dev/sdb, /dev/mmcblk0)
    IMAGE_FILE  Image file to flash (optional, defaults to output/rootfs.ext4)

EXAMPLES:
    $0 /dev/sdb                        # Flash default image to /dev/sdb
    $0 /dev/mmcblk0 custom.ext4        # Flash custom image to /dev/mmcblk0

SAFETY WARNING:
    This will COMPLETELY ERASE the target device!
    Make sure you specify the correct device.

EOF
}

# Function to validate arguments
validate_arguments() {
    if [ $# -lt 1 ]; then
        log_error "Device argument required"
        show_help
        exit 1
    fi
}

# Function to check if running as root
check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to validate device
validate_device() {
    local device="$1"
    
    if [ ! -b "$device" ]; then
        log_error "Device $device does not exist or is not a block device"
        exit 1
    fi
    
    # Check if device is mounted
    if mount | grep -q "$device"; then
        log_warn "Device $device appears to be mounted"
        log_info "Mounted partitions:"
        mount | grep "$device"
        echo
        read -p "Do you want to unmount all partitions? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            umount "${device}"* 2>/dev/null || true
            log_success "Partitions unmounted"
        else
            log_error "Cannot flash to mounted device"
            exit 1
        fi
    fi
}

# Function to find image file
find_image_file() {
    local image_file="$1"
    
    if [ -n "$image_file" ]; then
        if [ ! -f "$image_file" ]; then
            log_error "Image file not found: $image_file"
            exit 1
        fi
        echo "$image_file"
    else
        # Try to find default image
        local default_image="$OUTPUT_DIR/rootfs.ext4"
        if [ -f "$default_image" ]; then
            echo "$default_image"
        else
            log_error "Default image not found: $default_image"
            log_info "Please specify an image file or run build script first"
            exit 1
        fi
    fi
}

# Function to show device information
show_device_info() {
    local device="$1"
    
    log_info "Device information:"
    if command -v lsblk >/dev/null; then
        lsblk "$device" 2>/dev/null || true
    fi
    
    if command -v fdisk >/dev/null; then
        echo "  Size: $(fdisk -l "$device" 2>/dev/null | grep "Disk $device" | cut -d',' -f1 | cut -d':' -f2 | xargs || echo "Unknown")"
    fi
}

# Function to confirm flash operation
confirm_flash_operation() {
    local device="$1"
    local image_file="$2"
    
    echo "=========================================="
    echo "⚠️  FLASH CONFIRMATION ⚠️"
    echo "=========================================="
    log_warn "This will COMPLETELY ERASE $device!"
    log_info "Target device: $device"
    log_info "Image file: $image_file"
    log_info "Image size: $(du -h "$image_file" | cut -f1)"
    echo
    show_device_info "$device"
    echo
    log_warn "ALL DATA ON $device WILL BE LOST!"
    echo
    read -p "Are you absolutely sure you want to continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Flash operation cancelled"
        exit 0
    fi
}

# Function to flash image
flash_image() {
    local device="$1"
    local image_file="$2"
    
    log_info "Starting flash operation..."
    log_info "Source: $image_file"
    log_info "Target: $device"
    
    if dd if="$image_file" of="$device" bs=4M status=progress oflag=sync; then
        sync
        log_success "Image flashed successfully!"
        log_info "You can now safely remove the SD card"
    else
        log_error "Flash operation failed!"
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

    validate_arguments "$@"
    
    local device="$1"
    local image_file
    image_file=$(find_image_file "$2")

    echo "=========================================="
    echo "Robotics Controller Flash Script"
    echo "=========================================="

    check_root_privileges
    validate_device "$device"
    confirm_flash_operation "$device" "$image_file"
    flash_image "$device" "$image_file"
}

# Run main function
main "$@"
