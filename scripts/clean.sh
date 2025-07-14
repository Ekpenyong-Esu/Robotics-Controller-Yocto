#!/bin/bash
# Clean Script for Robotics Controller Yocto Build

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
OUTPUT_DIR="${PROJECT_ROOT}/output"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

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
    cat << 'EOF'
Usage: ./scripts/clean.sh [OPTIONS]

OPTIONS:
    -h, --help          Show help
    --all               Clean everything except conf/
    --build             Clean build artifacts (default)
    --downloads         Clean downloads cache
    --output            Clean output directory
    --sstate            Clean sstate-cache
    --recipe <name>     Clean specific recipe
    --list-recipes      List available recipes
    --disk-usage        Show disk usage

EOF
}
# Source Yocto environment if needed
source_yocto_env() {
    if ! command -v bitbake >/dev/null 2>&1; then
        if [ -f "$PROJECT_ROOT/poky/oe-init-build-env" ]; then
            log_info "Sourcing Yocto environment"
            set +u
            cd "$PROJECT_ROOT" && . poky/oe-init-build-env >/dev/null 2>&1
            set -u
        else
            log_error "oe-init-build-env not found"
            return 1
        fi
    fi
}

# List available recipes
list_recipes() {
    log_info "Listing available recipes"
    source_yocto_env || return 1

    # Show robotics recipes first, then others
    if bitbake-layers show-recipes 2>/dev/null | grep -i robotics; then
        echo
        log_info "All recipes (first 30):"
        bitbake-layers show-recipes 2>/dev/null | head -30
    else
        log_info "Available recipes (first 30):"
        bitbake-layers show-recipes 2>/dev/null | head -30
    fi
}

# Clean build directory
clean_build_directory() {
    log_info "Cleaning build artifacts"
    [ ! -d "$BUILD_DIR" ] && { log_warn "Build directory not found"; return 0; }

    # Clean standard directories
    for dir in tmp tmp-glibc cache; do
        [ -d "$BUILD_DIR/$dir" ] && rm -rf "${BUILD_DIR:?}/$dir" && log_success "Removed $dir"
    done

    # Clean log and lock files
    rm -f "$BUILD_DIR"/bitbake*.log "$BUILD_DIR"/*.lock 2>/dev/null

    # Clean other directories (preserve conf, downloads, sstate-cache)
    for dir in "$BUILD_DIR"/*/; do
        [ -d "$dir" ] || continue
        case "$(basename "$dir")" in
            conf|downloads|sstate-cache) continue ;;
            *) rm -rf "$dir" && log_success "Removed $(basename "$dir")" ;;
        esac
    done
}

# Clean downloads cache
clean_downloads_cache() {
    log_info "Cleaning downloads cache"
    [ -d "$BUILD_DIR/downloads" ] && rm -rf "${BUILD_DIR:?}/downloads" && log_success "Downloads cache removed"
}

# Clean output directory
clean_output_directory() {
    log_info "Cleaning output directory"
    [ -d "$OUTPUT_DIR" ] && rm -rf "${OUTPUT_DIR:?}" && log_success "Output directory removed"
}

# Clean sstate-cache
clean_sstate_cache() {
    log_info "Cleaning sstate-cache"
    [ -d "$BUILD_DIR/sstate-cache" ] && rm -rf "${BUILD_DIR:?}/sstate-cache" && log_success "sstate-cache removed"
}

# Clean specific recipe
clean_recipe() {
    local recipe="$1"
    [ -z "$recipe" ] && { log_error "Recipe name required"; return 1; }

    log_info "Cleaning recipe: $recipe"

    # Store current directory
    local original_dir
    original_dir="$(pwd)"

    # Source environment from project root (this will cd to build dir)
    source_yocto_env || return 1

    # Clean recipe
    if bitbake "$recipe" -c cleanall; then
        log_success "Recipe $recipe cleaned"
        bitbake "$recipe" -c cleansstate && log_success "Recipe sstate cleaned"
    else
        log_error "Recipe '$recipe' not found"
        log_info "Available recipes in meta-robotics:"
        find "$PROJECT_ROOT/meta-robotics" -name "*.bb" -exec basename {} .bb \; 2>/dev/null | sort
        cd "$original_dir"
        return 1
    fi

    cd "$original_dir"
}

# Clean everything except conf/
clean_all() {
    log_info "Cleaning everything except conf/"
    [ ! -d "$BUILD_DIR" ] && { log_warn "Build directory not found"; return 0; }

    for item in "$BUILD_DIR"/*; do
        [ -e "$item" ] || continue
        case "$(basename "$item")" in
            conf) log_info "Preserving: $(basename "$item")" ;;
            *) rm -rf "$item" && log_success "Removed: $(basename "$item")" ;;
        esac
    done

    clean_output_directory
}

# Show disk usage
show_disk_usage() {
    log_info "Current disk usage"

    if [ -d "$BUILD_DIR" ]; then
        echo "Build directory: $(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1)"
        for subdir in tmp tmp-glibc downloads sstate-cache cache; do
            [ -d "$BUILD_DIR/$subdir" ] && echo "  $subdir: $(du -sh "$BUILD_DIR/$subdir" 2>/dev/null | cut -f1)"
        done
    else
        echo "Build directory: Not found"
    fi

    [ -d "$OUTPUT_DIR" ] && echo "Output directory: $(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)"

    echo "Available space: $(df -h "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $4}')"
}


# Main function
main() {
    local action="build"
    local recipe_name=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            --all) action="all"; shift ;;
            --build) action="build"; shift ;;
            --downloads) action="downloads"; shift ;;
            --output) action="output"; shift ;;
            --sstate) action="sstate"; shift ;;
            --recipe) action="recipe"; recipe_name="${2:-}"; shift 2 ;;
            --list-recipes) action="list-recipes"; shift ;;
            --disk-usage) show_disk_usage; exit 0 ;;
            *) echo "Error: Unknown option $1" >&2; show_help; exit 1 ;;
        esac
    done

    case "$action" in
        all) clean_all ;;
        build) clean_build_directory ;;
        downloads) clean_downloads_cache ;;
        output) clean_output_directory ;;
        sstate) clean_sstate_cache ;;
        recipe) clean_recipe "$recipe_name" ;;
        list-recipes) list_recipes ;;
    esac
}

main "$@"
