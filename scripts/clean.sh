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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
    -o, --output        Clean only output directory
    -r, --recipe NAME   Clean specific recipe (e.g., rust-llvm-native)
    -f, --force         Force clean without confirmation

EXAMPLES:
    $0                           # Standard clean (build outputs only)
    $0 --all                     # Clean everything including downloads
    $0 --cache                   # Clean only package cache
    $0 --output                  # Clean only output directory
    $0 --recipe rust-llvm-native # Clean specific recipe

EOF
}

clean_build_outputs() {
    log_info "Cleaning Yocto build outputs..."

    if [ -d "$BUILD_DIR" ]; then
        # Clean Yocto build directories (check for both tmp and tmp-glibc)
        if [ -d "$BUILD_DIR/tmp-glibc" ]; then
            log_info "Removing $BUILD_DIR/tmp-glibc"
            if ! safe_remove_directory "$BUILD_DIR/tmp-glibc"; then
                log_warn "Failed to remove $BUILD_DIR/tmp-glibc completely"
            fi
        elif [ -d "$BUILD_DIR/tmp" ]; then
            log_info "Removing $BUILD_DIR/tmp"
            if ! safe_remove_directory "$BUILD_DIR/tmp"; then
                log_warn "Failed to remove $BUILD_DIR/tmp completely"
            fi
        fi

        # Clean other build artifacts
        if [ -d "$BUILD_DIR/cache" ]; then
            log_info "Removing $BUILD_DIR/cache"
            if ! safe_remove_directory "$BUILD_DIR/cache"; then
                log_warn "Failed to remove $BUILD_DIR/cache completely"
            fi
        fi
        
        # Clean sstate cache if present
        if [ -d "$BUILD_DIR/sstate-cache" ]; then
            log_info "Removing $BUILD_DIR/sstate-cache"
            if ! safe_remove_directory "$BUILD_DIR/sstate-cache"; then
                log_warn "Failed to remove $BUILD_DIR/sstate-cache completely"
            fi
        fi
    fi

    # Clean output directory (both symlinks and actual directories)
    if [ -e "${PROJECT_ROOT}/output" ]; then
        if [ -L "${PROJECT_ROOT}/output" ]; then
            log_info "Removing output symlink"
            rm -f "${PROJECT_ROOT}/output"
        elif [ -d "${PROJECT_ROOT}/output" ]; then
            log_info "Removing output directory and all contents"
            rm -rf "${PROJECT_ROOT}/output"
        fi
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

    # Clean output directory (both symlinks and actual directories)
    if [ -e "${PROJECT_ROOT}/output" ]; then
        if [ -L "${PROJECT_ROOT}/output" ]; then
            log_info "Removing output symlink"
            rm -f "${PROJECT_ROOT}/output"
        elif [ -d "${PROJECT_ROOT}/output" ]; then
            log_info "Removing output directory and all contents"
            rm -rf "${PROJECT_ROOT}/output"
        fi
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

clean_specific_recipe() {
    local recipe_name="$1"

    if [ -z "$recipe_name" ]; then
        log_warn "Recipe name not specified"
        return 1
    fi

    log_info "Cleaning specific recipe: $recipe_name"

    if [ ! -d "$BUILD_DIR" ]; then
        log_warn "Build directory does not exist: $BUILD_DIR"
        return 1
    fi

    # Source the Yocto environment to use bitbake commands
    local setup_env="$BUILD_DIR/../poky/oe-init-build-env"
    if [ ! -f "$setup_env" ]; then
        log_warn "Yocto environment setup script not found: $setup_env"
        log_info "Falling back to manual cleanup..."
    else
        log_info "Using bitbake to clean recipe: $recipe_name"
        cd "$BUILD_DIR"

        # Source environment and run bitbake clean commands
        set +e  # Don't exit on error for these commands
        . "$setup_env" "$BUILD_DIR" > /dev/null 2>&1

        # Clean the recipe work directory
        bitbake -c cleanall "$recipe_name" 2>/dev/null

        # Also clean the recipe's sstate
        bitbake -c cleansstate "$recipe_name" 2>/dev/null

        set -e  # Re-enable exit on error

        if [ $? -eq 0 ]; then
            log_success "Successfully cleaned recipe: $recipe_name using bitbake"
            return 0
        else
            log_warn "bitbake clean failed, falling back to manual cleanup..."
        fi
    fi

    # Manual cleanup fallback
    log_info "Performing manual cleanup for recipe: $recipe_name"

    # Clean work directories
    if [ -d "$BUILD_DIR/tmp/work" ]; then
        find "$BUILD_DIR/tmp/work" -name "*${recipe_name}*" -type d | while read -r dir; do
            if [ -d "$dir" ]; then
                log_info "Removing work directory: $(basename "$dir")"
                rm -rf "$dir"
            fi
        done
    fi

    # Clean sstate cache for the specific recipe
    if [ -d "$BUILD_DIR/sstate-cache" ]; then
        find "$BUILD_DIR/sstate-cache" -name "*${recipe_name}*" | while read -r file; do
            if [ -f "$file" ]; then
                log_info "Removing sstate file: $(basename "$file")"
                rm -f "$file"
            fi
        done
    fi

    # Clean stamps
    if [ -d "$BUILD_DIR/tmp/stamps" ]; then
        find "$BUILD_DIR/tmp/stamps" -name "*${recipe_name}*" | while read -r file; do
            if [ -f "$file" ]; then
                log_info "Removing stamp file: $(basename "$file")"
                rm -f "$file"
            fi
        done
    fi

    # Clean deploy directory
    if [ -d "$BUILD_DIR/tmp/deploy" ]; then
        find "$BUILD_DIR/tmp/deploy" -name "*${recipe_name}*" | while read -r file; do
            if [ -f "$file" ]; then
                log_info "Removing deploy file: $(basename "$file")"
                rm -f "$file"
            fi
        done
    fi

    log_success "Manual cleanup completed for recipe: $recipe_name"
}

# Clean only output directory
clean_output_only() {
    log_info "Cleaning output directory only..."

    # Clean output directory (both symlinks and actual directories)
    if [ -e "${PROJECT_ROOT}/output" ]; then
        if [ -L "${PROJECT_ROOT}/output" ]; then
            log_info "Removing output symlink"
            rm -f "${PROJECT_ROOT}/output"
        elif [ -d "${PROJECT_ROOT}/output" ]; then
            log_info "Removing output directory and all contents"
            rm -rf "${PROJECT_ROOT}/output"
        fi
        log_success "Output directory cleaned"
    else
        log_info "Output directory does not exist"
    fi
}

# Standalone disk usage reporting
show_disk_usage() {
    log_info "Disk usage for build directory:"
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

# Function to safely remove directories with better error handling
safe_remove_directory() {
    local dir="$1"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if [ ! -d "$dir" ]; then
            return 0  # Directory doesn't exist, success
        fi
        
        log_info "Attempt $attempt/$max_attempts to remove directory: $(basename "$dir")"
        
        # Check for processes using files in the directory
        if command -v lsof >/dev/null 2>&1; then
            local open_files
            open_files=$(lsof +D "$dir" 2>/dev/null | wc -l)
            if [ "$open_files" -gt 0 ]; then
                log_warn "Found $open_files open files in directory, attempting cleanup..."
                # Try to kill processes using the directory (be cautious)
                lsof +D "$dir" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u | while read -r pid; do
                    if [ -n "$pid" ] && [ "$pid" != "$$" ]; then
                        log_info "Terminating process $pid using directory files"
                        kill -TERM "$pid" 2>/dev/null || true
                    fi
                done
                sleep 2
            fi
        fi
        
        # Try to remove with different approaches
        if rm -rf "$dir" 2>/dev/null; then
            log_success "Successfully removed directory: $(basename "$dir")"
            return 0
        fi
        
        # If rm -rf failed, try alternative approaches
        log_warn "Standard removal failed, trying alternative methods..."
        
        # Try to remove files first, then directories
        if [ -d "$dir" ]; then
            find "$dir" -type f -delete 2>/dev/null || true
            find "$dir" -depth -type d -exec rmdir {} \; 2>/dev/null || true
        fi
        
        # Check if directory is now empty and try again
        if [ -d "$dir" ]; then
            if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
                rmdir "$dir" 2>/dev/null && return 0
            fi
        fi
        
        # If still exists, try with sudo (if available and user confirms)
        if [ -d "$dir" ] && [ $attempt -eq $max_attempts ]; then
            if command -v sudo >/dev/null 2>&1; then
                log_warn "Regular removal failed. Directory may contain files owned by root."
                echo -e "${YELLOW}Try removing with sudo? [y/N]${NC}"
                read -r response
                case "$response" in
                    [yY][eE][sS]|[yY])
                        if sudo rm -rf "$dir" 2>/dev/null; then
                            log_success "Successfully removed directory with sudo: $(basename "$dir")"
                            return 0
                        fi
                        ;;
                esac
            fi
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            log_info "Retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    # Final check - if directory still exists, report what's left
    if [ -d "$dir" ]; then
        log_error "Failed to completely remove directory: $(basename "$dir")"
        log_info "Remaining contents:"
        ls -la "$dir" 2>/dev/null | head -10 || true
        if [ "$(ls -A "$dir" 2>/dev/null | wc -l)" -gt 10 ]; then
            log_info "... and more files"
        fi
        return 1
    fi
    
    return 0
}

main() {
    log_info "Robotics Controller Build Cleaner"

    if [ "$CLEAN_TYPE" = "disk-usage" ]; then
        show_disk_usage
        exit 0
    fi

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
        "output")
            [ "$FORCE" != true ] && confirm_action "clean output directory only"
            clean_output_only
            ;;
        "build")
            [ "$FORCE" != true ] && confirm_action "clean build outputs (keeping downloads)"
            clean_meta_robotics
            clean_build_outputs
            ;;
        "recipe")
            if [ -z "$RECIPE_NAME" ]; then
                echo "Error: Recipe name must be specified with --recipe option"
                exit 1
            fi
            [ "$FORCE" != true ] && confirm_action "clean recipe: $RECIPE_NAME"
            clean_specific_recipe "$RECIPE_NAME"
            ;;
        *)
            [ "$FORCE" != true ] && confirm_action "clean build outputs (keeping downloads)"
            clean_meta_robotics
            clean_build_outputs
            ;;
    esac

    log_success "Clean operation completed"
}

# Default values
CLEAN_TYPE="build"
FORCE=false
RECIPE_NAME=""

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
        -o|--output)
            CLEAN_TYPE="output"
            shift
            ;;
        -r|--recipe)
            CLEAN_TYPE="recipe"
            if [[ $# -lt 2 ]]; then
                echo "Error: --recipe requires a recipe name"
                exit 1
            fi
            RECIPE_NAME="$2"
            shift 2
            ;;
        --disk-usage)
            CLEAN_TYPE="disk-usage"
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
