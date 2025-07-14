#!/bin/bash
# Simplified Save Configuration Script for Robotics Controller
# Author: Siddhant Jajoo
# Description: Save current build configuration

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
CONFIGS_DIR="${PROJECT_ROOT}/configs"

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
Usage: $0 [OPTIONS] [CONFIG_NAME]

Simplified script to save current build configuration.

ARGUMENTS:
    CONFIG_NAME     Name for the saved configuration

OPTIONS:
    -h, --help      Show this help message
    --list          List existing configurations
    --force         Overwrite existing configuration

EXAMPLES:
    $0 my-config            # Save current config as 'my-config'
    $0 --list               # List existing configs
    $0 --force my-config    # Force overwrite existing config

EOF
}

# Function to list existing configurations
list_configurations() {
    echo "=========================================="
    echo "Available Configurations"
    echo "=========================================="
    
    if [ -d "$CONFIGS_DIR" ]; then
        local configs
        configs=$(find "$CONFIGS_DIR" -name "*.conf" -type f 2>/dev/null | wc -l)
        
        if [ "$configs" -gt 0 ]; then
            log_info "Found $configs configuration(s):"
            find "$CONFIGS_DIR" -name "*.conf" -type f -exec basename {} .conf \; | sort
        else
            log_info "No configurations found"
        fi
    else
        log_info "No configs directory found"
    fi
}

# Function to validate configuration name
validate_config_name() {
    local config_name="$1"
    
    if [ -z "$config_name" ]; then
        log_error "Configuration name required"
        show_help
        exit 1
    fi
    
    # Check for valid filename characters
    if [[ ! "$config_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid configuration name. Use only letters, numbers, hyphens, and underscores."
        exit 1
    fi
}

# Function to check build configuration exists
check_build_config() {
    if [ ! -f "$BUILD_DIR/conf/local.conf" ] && [ ! -f "$BUILD_DIR/conf/bblayers.conf" ]; then
        log_error "Build configuration not found"
        log_info "Please run build script first to create configuration"
        exit 1
    fi
}

# Function to check if config exists
check_config_exists() {
    local config_name="$1"
    local force="$2"
    local config_file="${CONFIGS_DIR}/${config_name}.conf"
    
    if [ -f "$config_file" ] && [ "$force" != true ]; then
        log_error "Configuration '$config_name' already exists"
        log_info "Use --force to overwrite"
        exit 1
    fi
}

# Function to create configs directory
create_configs_directory() {
    mkdir -p "$CONFIGS_DIR"
}

# Function to save configuration
save_configuration() {
    local config_name="$1"
    local config_file="${CONFIGS_DIR}/${config_name}.conf"
    
    log_info "Saving configuration: $config_name"
    
    # Save the configuration files
    {
        echo "# Saved configuration: $config_name"
        echo "# Date: $(date)"
        echo "# Build directory: $BUILD_DIR"
        echo ""
        
        if [ -f "$BUILD_DIR/conf/local.conf" ]; then
            echo "# ===== local.conf ====="
            cat "$BUILD_DIR/conf/local.conf"
            echo ""
        fi
        
        if [ -f "$BUILD_DIR/conf/bblayers.conf" ]; then
            echo "# ===== bblayers.conf ====="
            cat "$BUILD_DIR/conf/bblayers.conf"
            echo ""
        fi
        
    } > "$config_file"
    
    log_success "Configuration saved to: $config_file"
}

# Function to show configuration info
show_config_info() {
    local config_name="$1"
    
    log_info "Configuration details:"
    echo "  Name: $config_name"
    echo "  Location: ${CONFIGS_DIR}/${config_name}.conf"
    echo "  Source build: $BUILD_DIR"
    
    # Show current machine and distro if available
    if [ -f "$BUILD_DIR/conf/local.conf" ]; then
        local machine
        machine=$(grep "^MACHINE" "$BUILD_DIR/conf/local.conf" 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
        echo "  Machine: $machine"
        
        local distro
        distro=$(grep "^DISTRO" "$BUILD_DIR/conf/local.conf" 2>/dev/null | cut -d'"' -f2 || echo "Default")
        echo "  Distro: $distro"
    fi
}

# Main execution function
main() {
    local action="save"
    local config_name=""
    local force=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --list)
                action="list"
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            *)
                config_name="$1"
                shift
                ;;
        esac
    done
    
    case "$action" in
        list)
            list_configurations
            ;;
        save)
            validate_config_name "$config_name"
            check_build_config
            create_configs_directory
            check_config_exists "$config_name" "$force"
            show_config_info "$config_name"
            save_configuration "$config_name"
            ;;
    esac
}

# Run main function
main "$@"
