#!/bin/bash

# Clean Build Script for Robotics Controller
# Removes all build artifacts and temporary files for Yocto

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Clean build artifacts for Embedded Robotics Controller with Yocto

OPTIONS:
    -h, --help          Show this help message
    -a, --all           Clean everything including downloads
    -b, --build-only    Clean only build outputs (keep downloads)
    -c, --cache         Clean shared state cache
    -d, --downloads     Clean only downloads
    -f, --force         Force clean without confirmation

EXAMPLES:
    $0                  # Standard clean (build outputs only)
    $0 --all            # Clean everything including downloads
    $0 --cache          # Clean only package cache

EOF
}

clean_build_outputs() {
    log_info "Cleaning Yocto build outputs..."

    if [ -d "$BUILD_DIR" ]; then
        # Clean Yocto build directories
        if [ -d "$BUILD_DIR/tmp" ]; then
            log_info "Removing $BUILD_DIR/tmp"
            rm -rf "$BUILD_DIR/tmp"
        fi

        # Clean other build artifacts
        if [ -d "$BUILD_DIR/cache" ]; then
            log_info "Removing $BUILD_DIR/cache"
            rm -rf "$BUILD_DIR/cache"
        fi
    fi

    # Remove symlinks
    if [ -L "${PROJECT_ROOT}/output" ]; then
        log_info "Removing output symlink"
        rm -f "${PROJECT_ROOT}/output"
    fi
}

clean_downloads() {
    log_info "Cleaning downloads..."

    # Clean Yocto downloads directory
    if [ -d "$BUILD_DIR/downloads" ]; then
        log_info "Removing $BUILD_DIR/downloads"
        rm -rf "$BUILD_DIR/downloads"
    fi

    # Alternative download location
    if [ -d "$BUILD_DIR/tmp/downloads" ]; then
        log_info "Removing $BUILD_DIR/tmp/downloads"
        rm -rf "$BUILD_DIR/tmp/downloads"
    fi

    # Clean specific archive files if any remain
    if [ -d "$BUILD_DIR" ]; then
        log_info "Searching for remaining archive files..."
        find "$BUILD_DIR" -name "*.tar.gz" -o -name "*.tar.bz2" -o -name "*.tar.xz" | while read -r file; do
            log_info "Removing $(basename "$file")"
            rm -f "$file"
        done
    fi
}

clean_cache() {
    log_info "Cleaning Yocto package cache..."

    if [ -d "$BUILD_DIR" ]; then
        # Clean sstate-cache directory
        if [ -d "$BUILD_DIR/sstate-cache" ]; then
            log_info "Removing sstate-cache in $BUILD_DIR/sstate-cache"
            rm -rf "$BUILD_DIR/sstate-cache"
        fi

        # Clean downloads if they exist in tmp
        if [ -d "$BUILD_DIR/tmp/deploy/sources" ]; then
            log_info "Removing download cache in $BUILD_DIR/tmp/deploy/sources"
            rm -rf "$BUILD_DIR/tmp/deploy/sources"
        fi
    fi
}

clean_all() {
    log_info "Performing complete clean..."

    if [ -d "$BUILD_DIR" ]; then
        log_info "Removing entire build directory: $BUILD_DIR"
        rm -rf "$BUILD_DIR"
    fi

    # Remove symlinks
    if [ -L "${PROJECT_ROOT}/output" ]; then
        log_info "Removing output symlink"
        rm -f "${PROJECT_ROOT}/output"
    fi
}

# Clean meta-robotics specific files
clean_meta_robotics() {
    log_info "Cleaning meta-robotics specific files..."

    local recipe_dir="${PROJECT_ROOT}/meta-robotics/recipes-robotics/robotics-controller"

    # Clean recipe temporary files using the recipe management script
    local manage_recipe_script="${PROJECT_ROOT}/scripts/manage-recipe.sh"
    if [ -x "$manage_recipe_script" ]; then
        log_info "Using recipe management script to clean recipe files..."
        "$manage_recipe_script" clean-recipe
    else
        # Manual cleanup if script not available
        log_info "Manually cleaning recipe work directories..."
        if [ -d "$BUILD_DIR/tmp/work" ]; then
            find "$BUILD_DIR/tmp/work" -name "*robotics-controller*" -type d -exec rm -rf {} + 2>/dev/null || true
        fi
    fi

    # Clean any backup files in recipe directory
    if [ -d "$recipe_dir" ]; then
        find "$recipe_dir" -name "*.bak" -delete 2>/dev/null || true
        find "$recipe_dir" -name "*.tmp" -delete 2>/dev/null || true
    fi

    # Clean sstate cache for robotics-controller specifically
    if [ -d "$BUILD_DIR/sstate-cache" ]; then
        find "$BUILD_DIR/sstate-cache" -name "*robotics-controller*" -delete 2>/dev/null || true
    fi
}

show_disk_usage() {
    log_info "Disk usage before clean:"
    if [ -d "$BUILD_DIR" ]; then
        du -sh "$BUILD_DIR" 2>/dev/null || echo "Build directory not found"
    else
        echo "No build directory found"
    fi
}

confirm_action() {
    local action="$1"
    echo -e "${YELLOW}This will $action. Continue? [y/N]${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            log_info "Operation cancelled"
            exit 0
            ;;
    esac
}

main() {
    log_info "Robotics Controller Build Cleaner"

    # Show current disk usage
    show_disk_usage

    case "$CLEAN_TYPE" in
        "all")
            [ "$FORCE" != true ] && confirm_action "remove ALL build artifacts and downloads"
            clean_meta_robotics
            clean_all
            ;;
        "cache")
            [ "$FORCE" != true ] && confirm_action "clean package download cache"
            clean_meta_robotics
            clean_cache
            ;;
        "downloads")
            [ "$FORCE" != true ] && confirm_action "clean downloaded packages"
            clean_downloads
            ;;
        "build")
            [ "$FORCE" != true ] && confirm_action "clean build outputs (keeping downloads)"
            clean_meta_robotics
            clean_build_outputs
            ;;
        *)
            [ "$FORCE" != true ] && confirm_action "clean build outputs (keeping downloads)"
            clean_meta_robotics
            clean_build_outputs
            ;;
    esac

    log_success "Clean operation completed"

    # Show disk usage after clean
    log_info "Disk usage after clean:"
    if [ -d "$BUILD_DIR" ]; then
        du -sh "$BUILD_DIR" 2>/dev/null || echo "Build directory removed"
    else
        echo "Build directory removed"
    fi
}

# Default values
CLEAN_TYPE="build"
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--all)
            CLEAN_TYPE="all"
            shift
            ;;
        -b|--build-only)
            CLEAN_TYPE="build"
            shift
            ;;
        -c|--cache)
            CLEAN_TYPE="cache"
            shift
            ;;
        -d|--downloads)
            CLEAN_TYPE="downloads"
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

main
