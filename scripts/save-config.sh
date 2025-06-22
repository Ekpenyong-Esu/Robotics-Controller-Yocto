#!/bin/bash

# Save Configuration Script for Robotics Controller
# Saves current Yocto Project configuration to the configs directory

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
CONFIGS_DIR="${PROJECT_ROOT}/configs"
MACHINE_DIR="${PROJECT_ROOT}/meta-robotics/conf/machine"

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
Usage: $0 [OPTIONS] [CONFIG_NAME]

Save current Buildroot configuration to configs directory

ARGUMENTS:
    CONFIG_NAME         Name for the saved configuration (without _defconfig suffix)
                       If not provided, will prompt for input

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Overwrite existing configuration without confirmation
    -l, --list          List existing configurations
    -d, --diff CONFIG   Show differences with existing configuration

EXAMPLES:
    $0                              # Interactive mode - prompts for name
    $0 beaglebone_robotics          # Save as beaglebone_robotics_defconfig
    $0 --force my_custom_config     # Force overwrite existing config
    $0 --list                       # List all existing configurations
    $0 --diff beaglebone_robotics   # Compare with existing config

EOF
}

check_yocto_env() {
    # Check if Yocto build environment exists
    if [ ! -d "$BUILD_DIR" ] || [ ! -d "$BUILD_DIR/conf" ]; then
        log_error "No Yocto build environment found in $BUILD_DIR"
        log_info "Run ./scripts/build.sh first to setup the Yocto environment"
        exit 1
    fi
    
    # Check for Yocto local.conf
    if [ ! -f "$BUILD_DIR/conf/local.conf" ]; then
        log_error "No local.conf file found in $BUILD_DIR/conf"
        log_info "Run './scripts/build.sh' first"
        exit 1
    fi
    
    # Success
    return 0
}

list_configurations() {
    log_info "Available configurations:"
    if [ -d "$CONFIGS_DIR" ]; then
        # Find directories containing configurations
        find "$CONFIGS_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r config_dir; do
            local name
            name=$(basename "$config_dir")
            
            # Get info about the configuration
            if [ -f "$config_dir/local.conf" ]; then
                local date
                date=$(stat -c%y "$config_dir/local.conf" | cut -d' ' -f1)
                
                # Get machine info
                local machine="unknown"
                if [ -f "$config_dir/machine.conf" ]; then
                    machine=$(basename "$config_dir/machine.conf" .conf)
                elif grep -q "^MACHINE" "$config_dir/local.conf"; then
                    machine=$(grep "^MACHINE" "$config_dir/local.conf" | cut -d'"' -f2)
                fi
                
                printf "  %-30s %-20s %s\n" "$name" "$machine" "$date"
            fi
        done
    else
        log_warn "No configs directory found"
    fi
}

show_config_diff() {
    local config_name="$1"
    local existing_config="${CONFIGS_DIR}/${config_name}"
    
    if [ ! -d "$existing_config" ]; then
        log_error "Configuration $config_name not found"
        return 1
    fi
    
    log_info "Generating configuration diff..."
    
    # Compare local.conf files
    if [ -f "$existing_config/local.conf" ] && [ -f "$BUILD_DIR/conf/local.conf" ]; then
        echo ""
        echo "Differences in local.conf:"
        echo "=========================="
        if diff -u "$existing_config/local.conf" "$BUILD_DIR/conf/local.conf"; then
            log_info "No differences found in local.conf"
        fi
    else
        log_warn "Cannot compare local.conf, file missing"
    fi
    
    # Compare bblayers.conf files
    if [ -f "$existing_config/bblayers.conf" ] && [ -f "$BUILD_DIR/conf/bblayers.conf" ]; then
        echo ""
        echo "Differences in bblayers.conf:"
        echo "============================"
        if diff -u "$existing_config/bblayers.conf" "$BUILD_DIR/conf/bblayers.conf"; then
            log_info "No differences found in bblayers.conf"
        fi
    else
        log_warn "Cannot compare bblayers.conf, file missing"
    fi
    
    # Compare machine configuration if available
    local current_machine
    current_machine=$(grep "^MACHINE" "$BUILD_DIR/conf/local.conf" | cut -d'"' -f2)
    
    if [ -f "$existing_config/machine.conf" ] && [ -f "$MACHINE_DIR/$current_machine.conf" ]; then
        echo ""
        echo "Differences in machine configuration:"
        echo "=================================="
        if diff -u "$existing_config/machine.conf" "$MACHINE_DIR/$current_machine.conf"; then
            log_info "No differences found in machine configuration"
        fi
    fi
}

validate_config_name() {
    local name="$1"
    
    # Check for valid characters (alphanumeric, underscore, hyphen)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid configuration name: $name"
        log_info "Use only alphanumeric characters, underscores, and hyphens"
        return 1
    fi
    
    # Check length
    if [ ${#name} -lt 3 ] || [ ${#name} -gt 50 ]; then
        log_error "Configuration name must be between 3 and 50 characters"
        return 1
    fi
    
    return 0
}

prompt_config_name() {
    local suggested_name
    suggested_name="custom_$(date +%Y%m%d)"
    
    echo -e "${BLUE}Enter configuration name:${NC}"
    echo -e "${YELLOW}Suggested: $suggested_name${NC}"
    read -r -p "Config name: " config_name
    
    # Use suggested name if empty
    if [ -z "$config_name" ]; then
        config_name="$suggested_name"
    fi
    
    echo "$config_name"
}

confirm_overwrite() {
    local config_name="$1"
    echo -e "${YELLOW}Configuration '$config_name' already exists. Overwrite? [y/N]${NC}"
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

save_configuration() {
    local config_name="$1"
    local force="$2"
    
    # Validate name
    if ! validate_config_name "$config_name"; then
        exit 1
    fi
    
    local config_dir="${CONFIGS_DIR}/${config_name}"
    local local_conf_dest="${config_dir}/local.conf"
    local bblayers_conf_dest="${config_dir}/bblayers.conf"
    local machine_conf_dest="${config_dir}/machine.conf"
    
    # Check if config already exists
    if [ -d "$config_dir" ] && [ "$force" != true ]; then
        confirm_overwrite "$config_name"
    fi
    
    # Create config directory
    mkdir -p "$config_dir"
    
    # Save the configuration
    log_info "Saving Yocto configuration as $config_name..."
    
    # Copy local.conf and bblayers.conf
    cp "$BUILD_DIR/conf/local.conf" "$local_conf_dest"
    cp "$BUILD_DIR/conf/bblayers.conf" "$bblayers_conf_dest"
    
    # Export current machine configuration
    local current_machine
    current_machine=$(grep "^MACHINE" "$BUILD_DIR/conf/local.conf" | cut -d'"' -f2)
    
    if [ -n "$current_machine" ] && [ -f "$MACHINE_DIR/$current_machine.conf" ]; then
        cp "$MACHINE_DIR/$current_machine.conf" "$machine_conf_dest"
        log_info "Machine configuration saved from $current_machine.conf"
    else
        log_warn "No machine configuration found for $current_machine"
    fi
    
    log_success "Configuration saved to $config_dir"
    
    # Show config summary
    local line_count_local
    line_count_local=$(wc -l < "$local_conf_dest")
    local line_count_bblayers
    line_count_bblayers=$(wc -l < "$bblayers_conf_dest")
    local size_local
    size_local=$(stat -c%s "$local_conf_dest")
    local size_bblayers
    size_bblayers=$(stat -c%s "$bblayers_conf_dest")
    
    log_info "Local configuration: $line_count_local lines ($size_local bytes)"
    log_info "Layer configuration: $line_count_bblayers lines ($size_bblayers bytes)"
    
    # Show key settings
    echo ""
    echo "Key configuration settings:"
    echo "=========================="
    echo "Machine: $current_machine"
    grep -E "^DISTRO|^PACKAGE_CLASSES|^EXTRA_IMAGE_FEATURES" "$local_conf_dest" | head -10 || true
}

main() {
    local config_name=""
    local force=false
    local list_only=false
    local diff_config=""
    
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
            -l|--list)
                list_only=true
                shift
                ;;
            -d|--diff)
                diff_config="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                config_name="$1"
                shift
                ;;
        esac
    done
    
    # Handle list-only mode
    if [ "$list_only" = true ]; then
        list_configurations
        exit 0
    fi
    
    # Check Yocto environment
    check_yocto_env
    log_info "Using Yocto build environment in: $BUILD_DIR"
    
    # Handle diff mode
    if [ -n "$diff_config" ]; then
        show_config_diff "$diff_config"
        exit 0
    fi
    
    # Get config name if not provided
    if [ -z "$config_name" ]; then
        local suggested_name
        suggested_name="custom_$(date +%Y%m%d)"
        config_name=$(prompt_config_name)
    fi
    
    # Save the configuration
    save_configuration "$config_name" "$force"
    
    log_success "Configuration management completed"
}

main "$@"
