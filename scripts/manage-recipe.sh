#!/bin/bash
# Simplified Recipe Management Script for Robotics Controller
# Author: Siddhant Jajoo
# Description: Manage meta-robotics recipes and source sync

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
META_ROBOTICS_DIR="${PROJECT_ROOT}/meta-robotics"
SRC_DIR="${PROJECT_ROOT}/robotics"

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
Usage: $0 [COMMAND] [OPTIONS]

Manage meta-robotics recipes and source synchronization

COMMANDS:
    sync                     Sync source code to meta-robotics layer
    validate                 Validate recipe structure
    clean                    Clean recipe build artifacts

OPTIONS:
    -h, --help              Show this help message

EXAMPLES:
    $0 sync                                                   # Sync source to recipe
    $0 validate                                              # Check recipe structure
    $0 clean                                                 # Clean build artifacts

EOF
}

# Check if source exists
check_source_exists() {
    if [ ! -d "$SRC_DIR/robotics-controller" ]; then
        log_error "Source not found: $SRC_DIR/robotics-controller"
        exit 1
    fi
}

# Create recipe directory structure
create_recipe_structure() {
    local recipe_dir="$META_ROBOTICS_DIR/recipes-robotics/robotics-controller"
    local files_dir="$recipe_dir/files"

    log_info "Creating recipe directory structure..."
    mkdir -p "$files_dir"
}

# Copy configuration files
copy_config_files() {
    local recipe_dir="$META_ROBOTICS_DIR/recipes-robotics/robotics-controller"
    local files_dir="$recipe_dir/files"

    if [ -d "$SRC_DIR/config" ]; then
        log_info "Copying configuration files..."
        cp -r "$SRC_DIR/config/"* "$files_dir/" 2>/dev/null || true
    fi
}

# Create systemd service file
create_systemd_service() {
    local recipe_dir="$META_ROBOTICS_DIR/recipes-robotics/robotics-controller"
    local files_dir="$recipe_dir/files"

    if [ ! -f "$files_dir/robotics-controller.service" ]; then
        log_info "Creating systemd service file..."
        cat > "$files_dir/robotics-controller.service" << 'EOF'
[Unit]
Description=Robotics Controller Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/robotics-controller/bin/robotics-controller
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    fi
}

# Create or update recipe file
create_recipe_file() {
    local recipe_dir="$META_ROBOTICS_DIR/recipes-robotics/robotics-controller"
    local recipe_file="$recipe_dir/robotics-controller_1.0.bb"

    if [ ! -f "$recipe_file" ]; then
        log_info "Creating recipe file..."
        cat > "$recipe_file" << 'EOF'
SUMMARY = "Robotics Controller Application"
DESCRIPTION = "Main robotics controller application for embedded systems"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://robotics-controller.service"

S = "${TOPDIR}/../robotics/robotics-controller"

inherit cmake systemd

SYSTEMD_SERVICE_${PN} = "robotics-controller.service"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/robotics-controller ${D}${bindir}/

    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/robotics-controller.service ${D}${systemd_unitdir}/system/
}

FILES_${PN} += "${systemd_unitdir}/system/robotics-controller.service"
EOF
    fi
}

# Sync source to meta-robotics
sync_source() {
    echo "=========================================="
    echo "Syncing Source to Meta-Robotics Recipe"
    echo "=========================================="

    check_source_exists
    create_recipe_structure
    copy_config_files
    create_systemd_service
    create_recipe_file

    local recipe_file="$META_ROBOTICS_DIR/recipes-robotics/robotics-controller/robotics-controller_1.0.bb"
    log_success "Source synchronized to meta-robotics layer"
    log_info "Recipe location: $recipe_file"
}

# Check meta-robotics layer
check_meta_robotics_layer() {
    if [ ! -d "$META_ROBOTICS_DIR" ]; then
        log_error "Meta-robotics layer not found: $META_ROBOTICS_DIR"
        return 1
    else
        log_success "Meta-robotics layer exists"
    fi
}

# Check recipe directory
check_recipe_directory() {
    local recipe_dir="$META_ROBOTICS_DIR/recipes-robotics/robotics-controller"

    if [ ! -d "$recipe_dir" ]; then
        log_error "Recipe directory not found: $recipe_dir"
        return 1
    else
        log_success "Recipe directory exists"
    fi
}

# Check recipe file
check_recipe_file() {
    local recipe_file="$META_ROBOTICS_DIR/recipes-robotics/robotics-controller/robotics-controller_1.0.bb"

    if [ ! -f "$recipe_file" ]; then
        log_error "Recipe file not found: $recipe_file"
        return 1
    else
        log_success "Recipe file exists"
    fi
}

# Check files directory
check_files_directory() {
    local files_dir="$META_ROBOTICS_DIR/recipes-robotics/robotics-controller/files"

    if [ ! -d "$files_dir" ]; then
        log_warn "Files directory not found: $files_dir"
    else
        log_success "Files directory exists"
        local file_count
        file_count=$(find "$files_dir" -type f | wc -l)
        log_info "Recipe files count: $file_count"
    fi
}

# Check source code
check_source_code() {
    if [ ! -d "$SRC_DIR/robotics-controller" ]; then
        log_error "Source code not found: $SRC_DIR/robotics-controller"
        return 1
    else
        log_success "Source code exists"
        local src_files
        src_files=$(find "$SRC_DIR/robotics-controller" -name "*.cpp" -o -name "*.h" | wc -l)
        log_info "Source files count: $src_files"
    fi
}

# Validate recipe structure
validate_recipe() {
    echo "=========================================="
    echo "Validating Recipe Structure"
    echo "=========================================="

    check_meta_robotics_layer
    check_recipe_directory
    check_recipe_file
    check_files_directory
    check_source_code

    log_success "Recipe structure validation completed"
}

# Clean build artifacts
clean_build_artifacts() {
    if [ -d "$BUILD_DIR/tmp-glibc" ]; then
        log_info "Cleaning build artifacts..."
        rm -rf "$BUILD_DIR/tmp-glibc/work"*robotics-controller* 2>/dev/null || true
        log_success "Build artifacts cleaned"
    fi
}

# Clean sstate cache
clean_sstate_cache() {
    if [ -d "$BUILD_DIR/sstate-cache" ]; then
        log_info "Cleaning sstate cache for robotics-controller..."
        find "$BUILD_DIR/sstate-cache" -name "*robotics-controller*" -delete 2>/dev/null || true
        log_success "Sstate cache cleaned"
    fi
}

# Clean recipe artifacts
clean_recipe() {
    echo "=========================================="
    echo "Cleaning Recipe Build Artifacts"
    echo "=========================================="

    clean_build_artifacts
    clean_sstate_cache

    log_success "Recipe cleanup completed"
}

# Main function
main() {

     # Parse arguments
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    case "$1" in
        sync)
            sync_source
            ;;
        validate)
            validate_recipe
            ;;
        clean)
            clean_recipe
            ;;
        -h|--help|help|"")
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
