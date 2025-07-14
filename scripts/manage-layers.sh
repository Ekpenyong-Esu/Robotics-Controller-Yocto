#!/bin/bash
# Simplified Layer Management Script for Robotics Controller
# Author: Siddhant Jajoo
# Description: Manage Yocto meta-layers

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

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

Manage Yocto meta-layers for Robotics Controller project

COMMANDS:
    list                      List currently configured layers
    add <name> <url>          Add a new meta-layer
    remove <name>             Remove a meta-layer
    
OPTIONS:
    -h, --help               Show this help message

EXAMPLES:
    $0 list                                                    # List all layers
    $0 add meta-ros https://github.com/ros/meta-ros           # Add ROS layer
    $0 remove meta-ros                                        # Remove ROS layer

EOF
}

# Check build environment
check_build_environment() {
    if [ ! -f "$BUILD_DIR/conf/bblayers.conf" ]; then
        log_error "Build environment not found"
        log_info "Please run: ./scripts/build.sh"
        exit 1
    fi
}

# List configured layers
list_layers() {
    echo "=========================================="
    echo "Currently Configured Meta-Layers"
    echo "=========================================="
    
    check_build_environment
    
    log_info "Layers in bblayers.conf:"
    grep -E "meta-|poky" "$BUILD_DIR/conf/bblayers.conf" | while read -r line; do
        local layer
        layer=$(basename "$(echo "$line" | sed 's/.*\///' | sed 's/ .*//' | sed 's/\\\///')")
        if [ -n "$layer" ] && [ "$layer" != "BBLAYERS" ]; then
            if [ -d "$PROJECT_ROOT/$layer" ]; then
                echo -e "  ${GREEN}✓${NC} $layer"
            else
                echo -e "  ${RED}✗${NC} $layer (missing)"
            fi
        fi
    done
}

# Validate layer arguments
validate_layer_args() {
    local command="$1"
    local layer_name="$2"
    local git_url="$3"
    
    case "$command" in
        add)
            if [ $# -lt 3 ]; then
                log_error "Usage: $0 add <layer-name> <git-url>"
                exit 1
            fi
            ;;
        remove)
            if [ $# -lt 2 ]; then
                log_error "Usage: $0 remove <layer-name>"
                exit 1
            fi
            ;;
    esac
}

# Clone layer repository
clone_layer() {
    local layer_name="$1"
    local git_url="$2"
    local layer_path="$PROJECT_ROOT/$layer_name"
    
    if [ ! -d "$layer_path" ]; then
        log_info "Cloning $layer_name from $git_url..."
        if git clone "$git_url" "$layer_path"; then
            log_success "Layer cloned successfully"
        else
            log_error "Failed to clone layer"
            exit 1
        fi
    else
        log_warn "Layer directory already exists: $layer_path"
    fi
}

# Add layer to bblayers.conf
add_to_bblayers() {
    local layer_name="$1"
    
    if ! grep -q "$layer_name" "$BUILD_DIR/conf/bblayers.conf"; then
        log_info "Adding layer to bblayers.conf..."
        # Create backup
        cp "$BUILD_DIR/conf/bblayers.conf" "$BUILD_DIR/conf/bblayers.conf.bak"
        # Add before the closing quote
        sed -i '/"/i\  ${TOPDIR}/../'"$layer_name"' \\' "$BUILD_DIR/conf/bblayers.conf"
        log_success "Layer added to build configuration"
    else
        log_warn "Layer already in bblayers.conf"
    fi
}

# Add a new layer
add_layer() {
    local layer_name="$1"
    local git_url="$2"
    
    echo "=========================================="
    echo "Adding Meta-Layer: $layer_name"
    echo "=========================================="
    
    check_build_environment
    clone_layer "$layer_name" "$git_url"
    add_to_bblayers "$layer_name"
    
    log_success "Layer $layer_name added successfully"
}

# Remove layer from bblayers.conf
remove_from_bblayers() {
    local layer_name="$1"
    
    if grep -q "$layer_name" "$BUILD_DIR/conf/bblayers.conf"; then
        log_info "Removing layer from bblayers.conf..."
        cp "$BUILD_DIR/conf/bblayers.conf" "$BUILD_DIR/conf/bblayers.conf.bak"
        sed -i "/$layer_name/d" "$BUILD_DIR/conf/bblayers.conf"
        log_success "Layer removed from build configuration"
    else
        log_warn "Layer not found in bblayers.conf"
    fi
}

# Remove layer directory
remove_layer_directory() {
    local layer_name="$1"
    local layer_path="$PROJECT_ROOT/$layer_name"
    
    if [ -d "$layer_path" ]; then
        echo -e "${YELLOW}Remove layer directory? This will delete all files!${NC}"
        read -p "Delete $layer_path? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$layer_path"
            log_success "Layer directory removed"
        else
            log_info "Layer directory kept"
        fi
    fi
}

# Remove a layer
remove_layer() {
    local layer_name="$1"
    
    echo "=========================================="
    echo "Removing Meta-Layer: $layer_name"
    echo "=========================================="
    
    check_build_environment
    remove_from_bblayers "$layer_name"
    remove_layer_directory "$layer_name"
    
    log_success "Layer $layer_name removed"
}

# Main function
main() {
     # Parse arguments
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    
    case "$1" in
        list)
            list_layers
            ;;
        add)
            shift
            validate_layer_args "add" "$@"
            add_layer "$@"
            ;;
        remove)
            shift
            validate_layer_args "remove" "$@"
            remove_layer "$@"
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
