#!/bin/bash

# Meta-Robotics Layer Synchronization Script
# This script manages copying and updating the meta-robotics layer to the Yocto build directory

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Configuration
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
META_SOURCE="${PROJECT_DIR}/meta-robotics"
BUILD_BASE="${PROJECT_DIR}/build"

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

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Meta-Robotics Layer Synchronization Tool

COMMANDS:
    sync [BUILD_DIR]        Sync meta-robotics layer to build directory
    check [BUILD_DIR]       Check if layer is up to date
    list                    List all build directories with meta-robotics
    clean [BUILD_DIR]       Remove meta-robotics layer from build directory
    validate                Validate meta-robotics layer structure
    help                    Show this help message

OPTIONS:
    -f, --force             Force sync even if target appears up-to-date
    -v, --verbose           Enable verbose output
    -n, --dry-run           Show what would be done without making changes

BUILD_DIR:
    Specific build directory to sync to (relative to project root)
    If not specified, will sync to all known build directories
    Examples: build, build-qemu, build-beaglebone

EXAMPLES:
    $0 sync                     # Sync to all build directories
    $0 sync build               # Sync to main build directory
    $0 sync build-qemu          # Sync to QEMU build directory
    $0 check                    # Check sync status of all builds
    $0 validate                 # Validate source layer structure
    $0 list                     # List all build directories

EOF
}

# Validate the source meta-robotics layer
validate_meta_layer() {
    log_info "Validating meta-robotics layer structure..."

    # Check if source directory exists
    if [ ! -d "$META_SOURCE" ]; then
        log_error "Source meta-robotics layer not found: $META_SOURCE"
        return 1
    fi

    # Check for required files and directories
    local required_files=(
        "conf/layer.conf"
        "recipes-core/images"
        "recipes-robotics"
    )

    local missing_files=()
    for file in "${required_files[@]}"; do
        if [ ! -e "$META_SOURCE/$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -ne 0 ]; then
        log_error "Missing required files/directories in meta-robotics layer:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi

    # Check layer.conf syntax
    if ! grep -q "BBFILE_COLLECTIONS.*robotics" "$META_SOURCE/conf/layer.conf"; then
        log_warn "layer.conf may have issues - missing or incorrect BBFILE_COLLECTIONS"
    fi

    log_success "Meta-robotics layer structure is valid"
    return 0
}

# Get list of build directories that should contain meta-robotics
get_build_directories() {
    local build_dirs=()

    # Main build directory
    if [ -d "$BUILD_BASE" ]; then
        build_dirs+=("build")
    fi

    # Multi-target build directories
    for dir in "$PROJECT_DIR"/build-*; do
        if [ -d "$dir" ]; then
            build_dirs+=("$(basename "$dir")")
        fi
    done

    printf '%s\n' "${build_dirs[@]}"
}

# Check if layer needs updating
needs_update() {
    local target_dir="$1"
    local source_dir="$META_SOURCE"

    # If target doesn't exist, it needs update
    if [ ! -d "$target_dir" ]; then
        return 0
    fi

    # Compare modification times
    if [ "$source_dir" -nt "$target_dir" ]; then
        return 0
    fi

    # Check if any source files are newer than target
    if find "$source_dir" -newer "$target_dir" -type f | grep -q .; then
        return 0
    fi

    return 1
}

# Sync meta-robotics layer to a specific build directory
sync_to_build_dir() {
    local build_dir_name="$1"
    local force="${2:-false}"
    local dry_run="${3:-false}"
    local verbose="${4:-false}"

    local full_build_path="$PROJECT_DIR/$build_dir_name"
    local target_meta_path="$full_build_path/meta-robotics"

    # Only sync if meta-robotics exists in project root
    if [ ! -d "$META_SOURCE" ]; then
        log_warn "meta-robotics layer does not exist in project root, skipping sync for $build_dir_name."
        return 0
    fi

    # Check if build directory exists
    if [ ! -d "$full_build_path" ]; then
        log_warn "Build directory does not exist: $build_dir_name"
        log_info "Skipping sync for non-existent build directory"
        return 0
    fi

    # Check if update is needed (unless forced)
    if [ "$force" = "false" ] && [ -d "$target_meta_path" ] && ! needs_update "$target_meta_path"; then
        if [ "$verbose" = "true" ]; then
            log_info "Meta-robotics layer in $build_dir_name is up to date"
        fi
        return 0
    fi

    log_info "Syncing meta-robotics layer to: $build_dir_name"

    if [ "$dry_run" = "true" ]; then
        echo "Would sync: $META_SOURCE -> $target_meta_path"
        if [ -d "$target_meta_path" ]; then
            echo "  (update existing)"
        else
            echo "  (create new)"
        fi
        return 0
    fi

    # Create backup if target exists
    if [ -d "$target_meta_path" ]; then
        local backup_path
        backup_path="${target_meta_path}.backup.$(date +%Y%m%d_%H%M%S)"
        if [ "$verbose" = "true" ]; then
            log_info "Creating backup: $(basename "$backup_path")"
        fi
        cp -r "$target_meta_path" "$backup_path"
    fi

    # Perform the sync
    local rsync_opts="-a --delete"
    if [ "$verbose" = "true" ]; then
        rsync_opts="$rsync_opts -v"
    fi

    if rsync $rsync_opts "$META_SOURCE/" "$target_meta_path/"; then
        log_success "Successfully synced to $build_dir_name"

        # Update the bblayers.conf if it exists and doesn't already reference the layer
        local bblayers_conf="$full_build_path/conf/bblayers.conf"
        if [ -f "$bblayers_conf" ] && ! grep -q "meta-robotics" "$bblayers_conf"; then
            log_info "Adding meta-robotics to bblayers.conf in $build_dir_name"
            # Add before the closing quote, maintaining the format
            sed -i '/^\s*"\s*$/i\  ${TOPDIR}/../meta-robotics \\' "$bblayers_conf"
        fi
    else
        log_error "Failed to sync to $build_dir_name"
        return 1
    fi
}

# Check sync status of build directories
check_sync_status() {
    local build_dirs
    mapfile -t build_dirs < <(get_build_directories)

    if [ ${#build_dirs[@]} -eq 0 ]; then
        log_warn "No build directories found"
        return 0
    fi

    log_info "Checking meta-robotics layer sync status..."
    echo

    for build_dir in "${build_dirs[@]}"; do
        local target_path="$PROJECT_DIR/$build_dir/meta-robotics"
        local status_symbol=""
        local status_text=""

        if [ ! -d "$target_path" ]; then
            status_symbol="${RED}✗${NC}"
            status_text="Not synced"
        elif needs_update "$target_path"; then
            status_symbol="${YELLOW}⚠${NC}"
            status_text="Needs update"
        else
            status_symbol="${GREEN}✓${NC}"
            status_text="Up to date"
        fi

        printf "  %s %-20s %s\n" "$status_symbol" "$build_dir" "$status_text"
    done
    echo
}

# List all build directories
list_build_directories() {
    local build_dirs
    mapfile -t build_dirs < <(get_build_directories)

    if [ ${#build_dirs[@]} -eq 0 ]; then
        log_warn "No build directories found"
        return 0
    fi

    log_info "Found build directories:"
    for build_dir in "${build_dirs[@]}"; do
        local full_path="$PROJECT_DIR/$build_dir"
        local meta_path="$full_path/meta-robotics"
        local size=""

        if [ -d "$meta_path" ]; then
            size=$(du -sh "$meta_path" 2>/dev/null | cut -f1 || echo "?")
            echo "  $build_dir (meta-robotics: $size)"
        else
            echo "  $build_dir (no meta-robotics)"
        fi
    done
}

# Clean meta-robotics layer from build directory
clean_build_dir() {
    local build_dir_name="$1"
    local dry_run="${2:-false}"

    local target_path="$PROJECT_DIR/$build_dir_name/meta-robotics"

    if [ ! -d "$target_path" ]; then
        log_info "No meta-robotics layer found in $build_dir_name"
        return 0
    fi

    log_info "Removing meta-robotics layer from: $build_dir_name"

    if [ "$dry_run" = "true" ]; then
        echo "Would remove: $target_path"
        return 0
    fi

    # Create backup before removal
    local backup_path
    backup_path="${target_path}.removed.$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup before removal: $(basename "$backup_path")"
    mv "$target_path" "$backup_path"

    # Remove from bblayers.conf if present
    local bblayers_conf="$PROJECT_DIR/$build_dir_name/conf/bblayers.conf"
    if [ -f "$bblayers_conf" ] && grep -q "meta-robotics" "$bblayers_conf"; then
        log_info "Removing meta-robotics from bblayers.conf"
        sed -i '/meta-robotics/d' "$bblayers_conf"
    fi

    log_success "Meta-robotics layer removed from $build_dir_name"
}

# Main sync function
main_sync() {
    local target_build_dir="$1"
    local force="$2"
    local dry_run="$3"
    local verbose="$4"

    # Validate source layer first
    if ! validate_meta_layer; then
        log_error "Source meta-robotics layer validation failed"
        return 1
    fi

    if [ -n "$target_build_dir" ]; then
        # Sync to specific build directory
        sync_to_build_dir "$target_build_dir" "$force" "$dry_run" "$verbose"
    else
        # Sync to all build directories
        local build_dirs
        mapfile -t build_dirs < <(get_build_directories)

        if [ ${#build_dirs[@]} -eq 0 ]; then
            log_warn "No build directories found to sync to"
            return 0
        fi

        log_info "Syncing to ${#build_dirs[@]} build directories..."
        for build_dir in "${build_dirs[@]}"; do
            sync_to_build_dir "$build_dir" "$force" "$dry_run" "$verbose"
        done
    fi
}

# Parse command line arguments
FORCE=false
VERBOSE=false
DRY_RUN=false
COMMAND=""
TARGET_BUILD_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help|help)
            show_usage
            exit 0
            ;;
        sync|check|list|clean|validate)
            COMMAND="$1"
            shift
            # Get optional build directory argument
            if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                TARGET_BUILD_DIR="$1"
                shift
            fi
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Default command is sync
if [ -z "$COMMAND" ]; then
    COMMAND="sync"
fi

# Execute the requested command
case "$COMMAND" in
    sync)
        main_sync "$TARGET_BUILD_DIR" "$FORCE" "$DRY_RUN" "$VERBOSE"
        ;;
    check)
        check_sync_status
        ;;
    list)
        list_build_directories
        ;;
    clean)
        if [ -z "$TARGET_BUILD_DIR" ]; then
            log_error "Build directory required for clean command"
            echo "Usage: $0 clean BUILD_DIR"
            exit 1
        fi
        clean_build_dir "$TARGET_BUILD_DIR" "$DRY_RUN"
        ;;
    validate)
        validate_meta_layer
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac
