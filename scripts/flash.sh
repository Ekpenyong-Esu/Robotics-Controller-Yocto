#!/bin/bash

# Flash Script for Robotics Controller
# Flashes the generated Yocto Project image to an SD card

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
DEPLOY_DIR="${BUILD_DIR}/tmp/deploy/images"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
Usage: $0 [OPTIONS] DEVICE

Flash Yocto Project image to SD card for Embedded Robotics Controller

ARGUMENTS:
    DEVICE              SD card device (e.g., /dev/sdb, /dev/mmcblk0)

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Skip safety confirmations
    -v, --verify        Verify written data after flashing
    -i, --image FILE    Use specific image file (auto-detect if not specified)
    -l, --list-devices  List available storage devices
    -s, --show-images   Show available images
    -m, --machine NAME  Machine to use (beaglebone-robotics, raspberrypi3, or rpi4-robotics)

EXAMPLES:
    $0 /dev/sdb                    # Flash to /dev/sdb with confirmations
    $0 --force /dev/mmcblk0        # Flash without confirmations
    $0 --verify /dev/sdb           # Flash and verify
    $0 --list-devices              # Show available devices
    $0 --show-images               # Show available images

SAFETY:
    This script includes multiple safety checks to prevent accidentally
    overwriting the wrong device. Always double-check the device name!

EOF
}

list_storage_devices() {
    log_info "Available storage devices:"
    echo "=========================="

    # List block devices with useful information
    if command -v lsblk &> /dev/null; then
        lsblk -d -o NAME,SIZE,TYPE,MODEL,VENDOR | grep -E "(disk|mmcblk)"
    else
        # Fallback to fdisk
        fdisk -l 2>/dev/null | grep -E "^Disk /dev/" | grep -v "loop"
    fi

    echo ""
    log_warn "Common SD card devices:"
    echo "  /dev/sdb, /dev/sdc, etc. (USB card readers)"
    echo "  /dev/mmcblk0 (built-in SD card reader)"
    echo ""
    log_warn "⚠️  Be VERY careful to select the correct device!"
}

show_available_images() {
    log_info "Available Yocto images:"
    echo "================================"

    local machine_dir="${DEPLOY_DIR}/${MACHINE:-beaglebone-robotics}"

    if [ ! -d "${DEPLOY_DIR}" ]; then
        log_error "Deploy directory not found: ${DEPLOY_DIR}"
        log_info "Run './scripts/build.sh' first, then build with 'bitbake robotics-controller-image'"
        return 1
    fi

    # List machine directories
    echo "Available machine directories:"
    for dir in "${DEPLOY_DIR}"/*; do
        if [ -d "$dir" ]; then
            echo "  - $(basename "$dir")"
        fi
    done
    echo ""

    # List images for selected machine
    if [ -d "$machine_dir" ]; then
        echo "Images for ${MACHINE:-beaglebone-robotics}:"
        find "$machine_dir" -name "*.wic.gz" -o -name "*.wic" -o -name "*.hddimg" -o -name "*.sdimg" | while read -r img; do
            local size
            size=$(stat -c%s "$img" 2>/dev/null || echo "0")
            local size_mb=$((size / 1024 / 1024))
            local date
            date=$(stat -c%y "$img" | cut -d' ' -f1)
            printf "  %-50s %s (%dMB)\n" "$(basename "$img")" "$date" "$size_mb"
        done
    else
        log_warn "No images found for machine: ${MACHINE:-beaglebone-robotics}"
        log_info "Available machine directories:"
        ls -la "${DEPLOY_DIR}" 2>/dev/null || echo "Directory not found"
    fi
}

find_image() {
    local custom_image="$1"

    if [ -n "$custom_image" ]; then
        if [ ! -f "$custom_image" ]; then
            log_error "Specified image not found: $custom_image"
            exit 1
        fi
        echo "$custom_image"
        return
    fi

    # Auto-detect image based on machine
    local machine_dir="${DEPLOY_DIR}/${MACHINE:-beaglebone-robotics}"

    # Check if machine directory exists
    if [ ! -d "$machine_dir" ]; then
        log_error "No image directory found for machine: ${MACHINE:-beaglebone-robotics}"
        log_info "Available machine directories:"
        ls -la "${DEPLOY_DIR}" 2>/dev/null || echo "Deploy directory not found"
        exit 1
    fi

    # Find the most recent image file
    local candidates=(
        "$(find "$machine_dir" -name "robotics-controller-image-*.wic.gz" | sort -r | head -1)"
        "$(find "$machine_dir" -name "robotics-controller-image-*.wic" | sort -r | head -1)"
        "$(find "$machine_dir" -name "robotics-controller-image-*.hddimg" | sort -r | head -1)"
        "$(find "$machine_dir" -name "robotics-controller-image-*.sdimg" | sort -r | head -1)"
    )

    for img in "${candidates[@]}"; do
        if [ -f "$img" ]; then
            echo "$img"
            return
        fi
    done

    log_error "No suitable image found in $machine_dir"
    log_info "Available files:"
    ls -la "$machine_dir" 2>/dev/null || echo "Directory not found"
    exit 1
}

validate_device() {
    local device="$1"

    # Check if device exists
    if [ ! -b "$device" ]; then
        log_error "Device $device does not exist or is not a block device"
        exit 1
    fi

    # Check if device is mounted
    if mount | grep -q "^$device"; then
        log_error "Device $device is currently mounted!"
        log_info "Unmount all partitions first:"
        mount | grep "^$device" | awk '{print $1}' | while read -r part; do
            echo "  sudo umount $part"
        done
        exit 1
    fi

    # Get device info
    local device_info=""
    local sectors=0
    if [ -f "/sys/block/$(basename "$device")/size" ]; then
        sectors=$(cat "/sys/block/$(basename "$device")/size")
        local size_mb=$((sectors * 512 / 1024 / 1024))
        device_info=" (${size_mb}MB)"
    fi

    log_info "Target device: $device$device_info"

    # Additional safety check - warn about small devices that might be system disks
    if [ -n "$device_info" ] && [ "$sectors" -gt 0 ]; then
        local size_gb=$((sectors * 512 / 1024 / 1024 / 1024))
        if [ "$size_gb" -gt 100 ]; then
            log_warn "Device is quite large (${size_gb}GB) - are you sure this is an SD card?"
        fi
    fi
}

confirm_flash() {
    local device="$1"
    local image="$2"

    echo ""
    echo -e "${RED}WARNING: This will completely erase $device!${NC}"
    echo -e "${YELLOW}Source image: $image${NC}"
    echo -e "${YELLOW}Target device: $device${NC}"
    echo ""
    echo -e "${RED}ALL DATA ON $device WILL BE LOST!${NC}"
    echo ""
    echo -e "${YELLOW}Type 'YES' to continue, anything else to abort:${NC}"
    read -r response

    if [ "$response" != "YES" ]; then
        log_info "Flash operation cancelled"
        exit 0
    fi
}

flash_image() {
    local device="$1"
    local image="$2"
    local verify="$3"

    log_info "Starting flash operation..."
    log_info "Image: $image"
    log_info "Device: $device"

    # Check if image is compressed
    local is_compressed=false
    local temp_image=""

    if [[ "$image" == *.gz ]]; then
        is_compressed=true
        log_info "Detected compressed image, decompressing..."
        temp_image=$(mktemp)
        gunzip -c "$image" > "$temp_image"
        image="$temp_image"
        log_info "Decompressed to temporary file: $temp_image"
    fi

    # Get image size for progress
    local img_size
    img_size=$(stat -c%s "$image")
    local img_size_mb=$((img_size / 1024 / 1024))

    log_info "Image size: ${img_size_mb}MB"

    # Flash the image
    local start_time
    start_time=$(date +%s)

    if command -v pv &> /dev/null; then
        # Use pv for progress bar if available
        log_info "Flashing with progress indicator..."
        pv "$image" | sudo dd of="$device" bs=4M conv=fsync status=none
    else
        # Fallback to regular dd
        log_info "Flashing (this may take several minutes)..."
        sudo dd if="$image" of="$device" bs=4M conv=fsync status=progress
    fi

    # Sync to ensure all data is written
    log_info "Syncing data to device..."
    sudo sync

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_success "Flash completed in ${duration} seconds"

    # Verify if requested
    if [ "$verify" = true ]; then
        log_info "Verifying written data..."
        local verify_size=$((img_size / 512))  # Convert to sectors

        if sudo dd if="$device" bs=512 count="$verify_size" | md5sum > /tmp/device_md5 && \
           md5sum "$image" > /tmp/image_md5; then

            local device_md5
            device_md5=$(cut -d' ' -f1 /tmp/device_md5)
            local image_md5
            image_md5=$(cut -d' ' -f1 /tmp/image_md5)

            if [ "$device_md5" = "$image_md5" ]; then
                log_success "Verification passed - data written correctly"
            else
                log_error "Verification failed - checksums don't match"
                exit 1
            fi
        else
            log_warn "Verification failed - could not read device"
        fi

        rm -f /tmp/device_md5 /tmp/image_md5
    fi

    # Clean up temporary decompressed image if needed
    if [ -n "$temp_image" ] && [ -f "$temp_image" ]; then
        log_info "Cleaning up temporary decompressed image..."
        rm -f "$temp_image"
    fi
}

# Check workspace source availability
check_workspace_source() {
    log_info "Verifying workspace source for recipe build..."

    # The recipe references workspace source directly via S = "${TOPDIR}/../src/robotics-controller"
    # Just verify that the required source exists
    local main_src_dir="${PROJECT_ROOT}/src/robotics-controller"
    local web_interface_dir="${PROJECT_ROOT}/src/web-interface"

    if [ ! -d "$main_src_dir" ]; then
        log_error "Workspace source directory not found: $main_src_dir"
        log_error "This is required for the recipe to build correctly"
        exit 1
    fi

    if [ ! -d "$web_interface_dir" ]; then
        log_error "Web interface directory not found: $web_interface_dir"
        log_error "This is required for the recipe to build correctly"
        exit 1
    fi

    log_info "Workspace source verified - recipe can build from:"
    log_info "  Application source: $main_src_dir"
    log_info "  Web interface: $web_interface_dir"
}

show_next_steps() {
    log_info "Flash completed successfully!"
    echo ""
    echo "Next steps:"
    echo "==========="
    echo "1. Safely remove the SD card:"
    echo "   sudo eject $DEVICE"
    echo ""
    echo "2. Insert SD card into your BeagleBone Black"
    echo ""
    echo "3. Connect serial console (115200 baud):"
    echo "   sudo minicom -D /dev/ttyUSB0 -b 115200"
    echo "   # or"
    echo "   sudo screen /dev/ttyUSB0 115200"
    echo ""
    echo "4. Power on the device and watch it boot"
    echo ""
    echo "5. Default login: root (no password)"
    echo ""
    echo "6. Test the robotics application:"
    echo "   /usr/bin/robotics-controller --test"
}

main() {
    local device=""
    local force=false
    local verify=false
    local custom_image=""
    local list_devices=false
    local show_images=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -v|--verify)
                verify=true
                shift
                ;;
            -i|--image)
                custom_image="$2"
                shift 2
                ;;
            -l|--list-devices)
                list_devices=true
                shift
                ;;
            -s|--show-images)
                show_images=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                device="$1"
                shift
                ;;
        esac
    done

    # Handle special modes
    if [ "$list_devices" = true ]; then
        list_storage_devices
        exit 0
    fi

    if [ "$show_images" = true ]; then
        show_available_images
        exit 0
    fi

    # Validate arguments
    if [ -z "$device" ]; then
        log_error "No device specified"
        echo ""
        show_help
        exit 1
    fi

    # Check if running as root for dd command
    if [ "$EUID" -eq 0 ]; then
        log_warn "Running as root - be extra careful!"
    fi

    # Find and validate image
    local image
    image=$(find_image "$custom_image")
    log_info "Using image: $image"

    # Validate device
    validate_device "$device"

    # Confirm operation unless forced
    if [ "$force" != true ]; then
        confirm_flash "$device" "$image"
    fi

    # Check and sync recipe if needed
    check_workspace_source

    # Perform the flash
    flash_image "$device" "$image" "$verify"

    # Show next steps
    DEVICE="$device" show_next_steps

    log_success "Flash operation completed successfully!"
}

main "$@"
