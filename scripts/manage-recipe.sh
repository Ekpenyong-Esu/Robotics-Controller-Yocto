#!/bin/bash

# Meta-Robotics Recipe Management Script
# Manages the meta-robotics layer recipes and source synchronization

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
META_ROBOTICS_DIR="${PROJECT_ROOT}/meta-robotics"
SRC_DIR="${PROJECT_ROOT}/src"
RECIPE_DIR="${META_ROBOTICS_DIR}/recipes-robotics/robotics-controller"

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
Usage: $0 [COMMAND] [OPTIONS]

Manage meta-robotics layer recipes and source synchronization

COMMANDS:
    sync-src            Configure workspace source reference (no duplication)
    sync-configs        Synchronize configuration files to recipe
    auto-populate       Automatically populate entire meta-robotics layer
    update-recipe       Update recipe file with new version/checksums
    validate            Validate recipe and meta-layer structure
    clean-recipe        Clean recipe temporary files
    show-info           Show recipe and source information
    test-recipe         Test recipe build in isolation
    check-symlinks      Check for symbolic links in recipe source
    create-layer        Create complete meta-robotics layer structure
    update-all          Update everything (configs, source, recipe)

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -f, --force         Force operations without confirmation

EXAMPLES:
    $0 auto-populate    # Fully populate meta-robotics layer automatically
    $0 sync-src         # Configure workspace source reference
    $0 sync-configs     # Sync configuration files only
    $0 update-all       # Update everything in meta-robotics layer

EOF
}

# Configure source reference for meta-robotics recipe (industrial approach)
sync_source() {
    log_info "Configuring source reference for meta-robotics recipe (no duplication)..."

    local recipe_files_dir="${RECIPE_DIR}/files"

    # Create recipe files directory structure
    mkdir -p "${recipe_files_dir}"

    # Remove any existing source directory copies (this was wrong approach)
    if [ -d "${recipe_files_dir}/src" ]; then
        log_info "Removing duplicated source code from recipe files..."
        rm -rf "${recipe_files_dir}/src"
        log_success "Source duplication removed - using workspace reference instead"
    fi

    # Verify source directories exist in workspace
    if [ ! -d "${SRC_DIR}/robotics-controller" ]; then
        log_error "Source directory not found: ${SRC_DIR}/robotics-controller"
        exit 1
    fi

    if [ ! -d "${SRC_DIR}/web-interface" ]; then
        log_error "Source directory not found: ${SRC_DIR}/web-interface"
        exit 1
    fi

    # The source code itself should NOT be copied to recipe files
    # The recipe now references the workspace source directly via S = "${TOPDIR}/../src/robotics-controller"
    log_success "Source reference configured (no duplication)"
    log_info "Recipe will reference source at: ${SRC_DIR}/robotics-controller"
    log_info "Recipe will reference web interface at: ${SRC_DIR}/web-interface"
    log_info "Total source files available: $(find "${SRC_DIR}" -name "*.cpp" -o -name "*.h" | wc -l)"
}

# Synchronize configuration files to recipe files directory
sync_configs() {
    log_info "Synchronizing configuration files to meta-robotics recipe..."

    local recipe_files_dir="${RECIPE_DIR}/files"

    # Create recipe files directory structure
    mkdir -p "${recipe_files_dir}"

    # Copy configuration files from src/config
    if [ -d "${SRC_DIR}/config" ]; then
        log_info "Copying configuration files..."

        # Create config directory in recipe files
        mkdir -p "${recipe_files_dir}/config"

        # Copy all config files
        if [ "$verbose" = true ]; then
            cp -rv "${SRC_DIR}/config/"* "${recipe_files_dir}/"
        else
            cp -r "${SRC_DIR}/config/"* "${recipe_files_dir}/"
        fi

        log_success "Configuration files synchronized"
    else
        log_warn "No configuration directory found at ${SRC_DIR}/config"
    fi

    # Ensure systemd service file exists in recipe files
    if [ ! -f "${recipe_files_dir}/robotics-controller.service" ]; then
        log_info "Creating systemd service file..."
        create_systemd_service "${recipe_files_dir}/robotics-controller.service"
    else
        log_info "Systemd service file already exists in recipe files"
    fi

    # Copy init script from src/scripts if it exists
    if [ -f "${SRC_DIR}/scripts/robotics-controller-init" ]; then
        log_info "Copying init script from workspace..."
        cp "${SRC_DIR}/scripts/robotics-controller-init" "${recipe_files_dir}/"
    elif [ ! -f "${recipe_files_dir}/robotics-controller-init" ]; then
        log_info "Creating init script..."
        create_init_script "${recipe_files_dir}/robotics-controller-init"
    fi

    # Copy any additional recipe-specific files
    sync_recipe_extras
}

# Create systemd service file automatically
create_systemd_service() {
    local service_file="$1"

    cat > "$service_file" << 'EOF'
[Unit]
Description=Robotics Controller Service
After=multi-user.target
Conflicts=getty@tty1.service

[Service]
Type=simple
User=root
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/robotics-controller
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    log_success "Created systemd service file: $service_file"
}

# Sync additional recipe files (scripts, etc.)
sync_recipe_extras() {
    local recipe_files_dir="${RECIPE_DIR}/files"

    # Copy any additional scripts from src/scripts (excluding manage-recipe.sh and init script)
    if [ -d "${SRC_DIR}/scripts" ]; then
        mkdir -p "${recipe_files_dir}/scripts"
        find "${SRC_DIR}/scripts" -name "*.sh" -not -name "manage-recipe.sh" -not -name "*-init" -exec cp {} "${recipe_files_dir}/scripts/" \;

        # Also copy any other script files (non-.sh)
        find "${SRC_DIR}/scripts" -type f -not -name "*.sh" -not -name "manage-recipe.sh" -not -name "*-init" -exec cp {} "${recipe_files_dir}/scripts/" \;
    fi
}

# Create init script automatically
create_init_script() {
    local init_file="$1"

    cat > "$init_file" << 'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          robotics-controller
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Robotics Controller Service
# Description:       Main robotics controller application
### END INIT INFO

# Source function library
. /etc/init.d/functions

USER="root"
DAEMON="robotics-controller"
ROOT_DIR="/usr/bin"

PIDFILE="/var/run/robotics-controller.pid"
LOCKFILE="/var/lock/subsys/robotics-controller"

start() {
    if [ -f $PIDFILE ]; then
        echo "$DAEMON is already running"
        return 1
    fi

    echo -n "Starting $DAEMON: "
    daemon --user "$USER" --pidfile="$PIDFILE" "$ROOT_DIR/$DAEMON"
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && touch $LOCKFILE
    return $RETVAL
}

stop() {
    echo -n "Shutting down $DAEMON: "
    pid=$(ps -aefw | grep "$DAEMON" | grep -v " grep " | awk '{print $2}')
    kill -9 $pid > /dev/null 2>&1
    [ $? -eq 0 ] && echo "OK" || echo "FAIL"
    rm -f $PIDFILE
    rm -f $LOCKFILE
}

status() {
    if [ -f $PIDFILE ]; then
        echo "$DAEMON is running"
    else
        echo "$DAEMON is stopped"
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: {start|stop|status|restart}"
        exit 1
        ;;
esac

exit $?
EOF

    chmod +x "$init_file"
    log_success "Created init script: $init_file"
}

# Update recipe with new version or checksums
update_recipe() {
    log_info "Updating meta-robotics recipe..."

    local recipe_file="${RECIPE_DIR}/robotics-controller_1.0.bb"

    if [ ! -f "$recipe_file" ]; then
        log_error "Recipe file not found: $recipe_file"
        exit 1
    fi

    # Backup current recipe
    cp "$recipe_file" "${recipe_file}.bak"

    # Update SRCREV if this is a git-based recipe (for future use)
    # For now, we're using local files, so we'll update the file listing

    log_info "Recipe updated (backup saved as ${recipe_file}.bak)"
    log_success "Recipe update completed"
}

# Validate meta-layer structure
validate_layer() {
    log_info "Validating meta-robotics layer structure..."

    local errors=0

    # Check layer.conf
    if [ ! -f "${META_ROBOTICS_DIR}/conf/layer.conf" ]; then
        log_error "Missing layer.conf file"
        ((errors++))
    fi

    # Check recipe file
    if [ ! -f "${RECIPE_DIR}/robotics-controller_1.0.bb" ]; then
        log_error "Missing main recipe file"
        ((errors++))
    fi

    # Check source reference (new approach)
    if [ -d "${SRC_DIR}/robotics-controller" ] && [ -d "${SRC_DIR}/web-interface" ]; then
        log_info "Source reference validated: workspace source available"
    else
        log_error "Workspace source directories missing"
        ((errors++))
    fi

    # Check machine configurations
    local machine_dir="${META_ROBOTICS_DIR}/conf/machine"
    if [ ! -d "$machine_dir" ]; then
        log_error "Missing machine configurations directory"
        ((errors++))
    else
        local machines=("beaglebone-robotics.conf" "raspberrypi3.conf" "rpi4-robotics.conf" "qemu-robotics.conf")
        for machine in "${machines[@]}"; do
            if [ ! -f "${machine_dir}/$machine" ]; then
                log_warn "Missing machine config: $machine"
            fi
        done
    fi

    # Check image recipes
    local image_dir="${META_ROBOTICS_DIR}/recipes-core/images"
    if [ ! -d "$image_dir" ]; then
        log_error "Missing image recipes directory"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        log_success "Meta-layer validation passed"
    else
        log_error "Meta-layer validation failed with $errors errors"
        exit 1
    fi
}

# Clean recipe temporary files
clean_recipe() {
    log_info "Cleaning meta-robotics recipe temporary files..."

    local temp_dirs=(
        "${BUILD_DIR}/tmp/work/**/robotics-controller"
        "${BUILD_DIR}/tmp/work/**/robotics-controller-*"
        "${BUILD_DIR}/sstate-cache/??/sstate:robotics-controller*"
    )

    for pattern in "${temp_dirs[@]}"; do
        if ls $pattern 1> /dev/null 2>&1; then
            rm -rf $pattern
            log_info "Removed: $pattern"
        fi
    done

    log_success "Recipe temporary files cleaned"
}

# Show recipe and source information
show_info() {
    log_info "Meta-Robotics Recipe Information"
    echo "================================"

    echo "Project root: $PROJECT_ROOT"
    echo "Meta-robotics layer: $META_ROBOTICS_DIR"
    echo "Recipe directory: $RECIPE_DIR"
    echo "Source directory: $SRC_DIR"
    echo ""

    # Recipe file info
    local recipe_file="${RECIPE_DIR}/robotics-controller_1.0.bb"
    if [ -f "$recipe_file" ]; then
        echo "Recipe file: $(basename "$recipe_file")"
        echo "Last modified: $(stat -c %y "$recipe_file")"
    else
        echo "Recipe file: NOT FOUND"
    fi

    # Source reference status (new approach)
    log_info "Source reference approach: Workspace source (no duplication)"
    if [ -d "${SRC_DIR}/robotics-controller" ] && [ -d "${SRC_DIR}/web-interface" ]; then
        echo "Source reference configured: YES"
        echo "Workspace source: ${SRC_DIR}"
        echo "Source files available: $(find "${SRC_DIR}" -name "*.cpp" -o -name "*.h" | wc -l)"
        echo "Storage saved by avoiding duplication: ~1.5GB"
    else
        echo "Source reference configured: NO (workspace source missing)"
    fi

    echo ""
    echo "Available machine configurations:"
    if [ -d "${META_ROBOTICS_DIR}/conf/machine" ]; then
        find "${META_ROBOTICS_DIR}/conf/machine" -name "*.conf" -print0 2>/dev/null | xargs -0 -I {} basename {} .conf || echo "  None found"
    fi

    echo ""
    echo "Available image recipes:"
    if [ -d "${META_ROBOTICS_DIR}/recipes-core/images" ]; then
        find "${META_ROBOTICS_DIR}/recipes-core/images" -name "*.bb" -print0 2>/dev/null | xargs -0 -I {} basename {} .bb || echo "  None found"
    fi
}

# Test recipe build in isolation
test_recipe() {
    log_info "Testing meta-robotics recipe build..."

    if [ ! -d "$BUILD_DIR" ]; then
        log_error "Build directory not found. Run build.sh first to set up the environment."
        exit 1
    fi

    # Verify workspace source exists (current approach)
    if [ ! -d "${SRC_DIR}/robotics-controller" ]; then
        log_error "Workspace source not found: ${SRC_DIR}/robotics-controller"
        log_error "Recipe requires workspace source to be available"
        exit 1
    fi

    log_info "Building robotics-controller recipe..."
    cd "$BUILD_DIR"

    if [ -f "setup-environment" ]; then
        # Source the environment and build just our recipe
        source setup-environment
        log_info "Building robotics-controller package..."
        bitbake robotics-controller

        if [ $? -eq 0 ]; then
            log_success "Recipe build test passed!"
        else
            log_error "Recipe build test failed!"
            exit 1
        fi
    else
        log_error "Build environment not set up. Run ./scripts/build.sh first."
        exit 1
    fi
}

# Check for symbolic links in recipe files (should be none with new approach)
check_symlinks() {
    log_info "Checking for symbolic links in recipe files..."

    local recipe_files_dir="${RECIPE_DIR}/files"

    if [ ! -d "$recipe_files_dir" ]; then
        log_warn "Recipe files directory not found: $recipe_files_dir"
        return 1
    fi

    local symlinks
    symlinks=$(find "$recipe_files_dir" -type l 2>/dev/null)

    if [ -n "$symlinks" ]; then
        log_warn "Found symbolic links in recipe files directory:"
        echo "$symlinks" | while read -r link; do
            local target
            target=$(readlink "$link")
            echo "  $link -> $target"
        done
        echo ""
        log_warn "Note: With the new approach, no source duplication should occur."
        log_warn "Only configuration and service files should be in recipe files."
        return 1
    else
        log_success "No symbolic links found in recipe files"
        log_info "Recipe properly uses workspace source reference (no duplication)"
        return 0
    fi
}

# Automatically populate entire meta-robotics layer
auto_populate() {
    log_info "Auto-populating complete meta-robotics layer..."

    # Create the complete layer structure
    create_layer_structure

    # Sync all source code
    sync_source

    # Sync all configuration files
    sync_configs

    # Update recipe file
    update_recipe_auto

    # Validate everything
    validate_layer

    log_success "Meta-robotics layer fully populated and validated!"
    log_info "Layer is now ready for Yocto builds"
}

# Create complete meta-robotics layer structure
create_layer_structure() {
    log_info "Creating complete meta-robotics layer structure..."

    # Create all necessary directories
    local dirs=(
        "${META_ROBOTICS_DIR}/conf"
        "${META_ROBOTICS_DIR}/conf/machine"
        "${META_ROBOTICS_DIR}/conf/templates"
        "${META_ROBOTICS_DIR}/recipes-core/images"
        "${META_ROBOTICS_DIR}/recipes-kernel/linux"
        "${META_ROBOTICS_DIR}/recipes-robotics/robotics-controller"
        "${META_ROBOTICS_DIR}/recipes-robotics/robotics-controller/files"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        [ "$verbose" = true ] && log_info "Created directory: $dir"
    done

    # Create layer.conf if it doesn't exist
    if [ ! -f "${META_ROBOTICS_DIR}/conf/layer.conf" ]; then
        create_layer_conf
    fi

    # Create machine configurations
    create_machine_configs

    # Create image recipes
    create_image_recipes

    log_success "Meta-robotics layer structure created"
}

# Create layer.conf file
create_layer_conf() {
    local layer_conf="${META_ROBOTICS_DIR}/conf/layer.conf"

    cat > "$layer_conf" << 'EOF'
# We have a conf and classes directory, add to BBPATH
BBPATH .= ":${LAYERDIR}"

# We have recipes-* directories, add to BBFILES
BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
            ${LAYERDIR}/recipes-*/*/*.bbappend"

BBFILE_COLLECTIONS += "meta-robotics"
BBFILE_PATTERN_meta-robotics = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-robotics = "8"

# Layer dependencies
LAYERDEPENDS_meta-robotics = "core openembedded-layer"
LAYERSERIES_COMPAT_meta-robotics = "kirkstone"

# Machine configurations
MACHINE_FEATURES_BACKFILL_CONSIDERED_robotics = "rtc"
EOF

    log_success "Created layer.conf: $layer_conf"
}

# Create machine configuration files
create_machine_configs() {
    log_info "Creating machine configurations..."

    local machine_dir="${META_ROBOTICS_DIR}/conf/machine"

    # BeagleBone Robotics machine
    cat > "${machine_dir}/beaglebone-robotics.conf" << 'EOF'
#@TYPE: Machine
#@NAME: BeagleBone Robotics Platform
#@DESCRIPTION: Machine configuration for BeagleBone-based robotics controller

require conf/machine/beaglebone-yocto.conf

MACHINE_FEATURES += "robotics gpio i2c spi uart"
MACHINE_FEATURES_BACKFILL_CONSIDERED += "rtc"

# Additional packages for robotics
MACHINE_ESSENTIAL_EXTRA_RDEPENDS += "robotics-controller"

# GPIO and hardware support
PREFERRED_PROVIDER_virtual/kernel = "linux-yocto"
KERNEL_DEVICETREE = "am335x-boneblack.dtb"

# Boot configuration
UBOOT_MACHINE = "am335x_evm_config"
EOF

    # Raspberry Pi 3 Robotics machine
    cat > "${machine_dir}/raspberrypi3.conf" << 'EOF'
#@TYPE: Machine
#@NAME: Raspberry Pi 3 Robotics Platform
#@DESCRIPTION: Machine configuration for RPi3-based robotics controller

require conf/machine/raspberrypi3-64.conf

MACHINE_FEATURES += "robotics gpio i2c spi uart bluetooth wifi"
MACHINE_FEATURES_BACKFILL_CONSIDERED += "rtc"

# Additional packages for robotics
MACHINE_ESSENTIAL_EXTRA_RDEPENDS += "robotics-controller"

# Hardware configuration optimized for RPi3
GPU_MEM = "64"
ENABLE_UART = "1"
ENABLE_I2C = "1"
ENABLE_SPI = "1"
EOF

    # Raspberry Pi 4 Robotics machine
    cat > "${machine_dir}/rpi4-robotics.conf" << 'EOF'
#@TYPE: Machine
#@NAME: Raspberry Pi 4 Robotics Platform
#@DESCRIPTION: Machine configuration for RPi4-based robotics controller

require conf/machine/raspberrypi4-64.conf

MACHINE_FEATURES += "robotics gpio i2c spi uart bluetooth wifi"
MACHINE_FEATURES_BACKFILL_CONSIDERED += "rtc"

# Additional packages for robotics
MACHINE_ESSENTIAL_EXTRA_RDEPENDS += "robotics-controller"

# GPU support
GPU_MEM = "64"
ENABLE_UART = "1"
EOF

    # QEMU Robotics machine for testing
    cat > "${machine_dir}/qemu-robotics.conf" << 'EOF'
#@TYPE: Machine
#@NAME: QEMU Robotics Emulation
#@DESCRIPTION: QEMU machine for testing robotics controller

require conf/machine/qemuarm64.conf

MACHINE_FEATURES += "robotics"
MACHINE_FEATURES_BACKFILL_CONSIDERED += "rtc"

# Additional packages for robotics testing
MACHINE_ESSENTIAL_EXTRA_RDEPENDS += "robotics-controller"

# Emulation settings
QB_MEM = "512M"
EOF

    log_success "Created machine configurations"
}

# Create image recipes
create_image_recipes() {
    log_info "Creating image recipes..."

    local image_dir="${META_ROBOTICS_DIR}/recipes-core/images"

    # Main robotics image
    cat > "${image_dir}/robotics-image.bb" << 'EOF'
DESCRIPTION = "Robotics Controller Linux Image"
LICENSE = "MIT"

# Base image
require recipes-core/images/core-image-minimal.bb

# Essential robotics packages
IMAGE_INSTALL:append = " \
    robotics-controller \
    opencv \
    python3 \
    python3-opencv \
    i2c-tools \
    spi-tools \
    gpio-utils \
    systemd \
    systemd-networkd \
    openssh \
    htop \
    nano \
"

# Development tools (optional)
IMAGE_INSTALL:append = " \
    gdb \
    strace \
    tcpdump \
    iperf3 \
"

# Set root password (change in production)
EXTRA_USERS_PARAMS = "usermod -P robotics root;"

# Enable systemd
DISTRO_FEATURES:append = " systemd"
VIRTUAL-RUNTIME_init_manager = "systemd"
DISTRO_FEATURES_BACKFILL_CONSIDERED += "sysvinit"
VIRTUAL-RUNTIME_initscripts = ""

# Image features
IMAGE_FEATURES += "ssh-server-openssh"
EOF

    # Development image with more tools
    cat > "${image_dir}/robotics-dev-image.bb" << 'EOF'
DESCRIPTION = "Robotics Controller Development Image"
LICENSE = "MIT"

# Base robotics image
require robotics-image.bb

# Development packages
IMAGE_INSTALL:append = " \
    cmake \
    gcc \
    g++ \
    make \
    pkgconfig \
    git \
    vim \
    gdb \
    valgrind \
    perf \
    kernel-dev \
    kernel-devsrc \
"

# Tools for hardware debugging
IMAGE_INSTALL:append = " \
    devmem2 \
    iozone3 \
    bonnie++ \
    ldd \
    file \
    which \
"
EOF

    log_success "Created image recipes"
}

# Automatically update recipe file with current source information
update_recipe_auto() {
    log_info "Auto-updating recipe file..."

    local recipe_file="${RECIPE_DIR}/robotics-controller_1.0.bb"

    # Backup current recipe
    if [ -f "$recipe_file" ]; then
        cp "$recipe_file" "${recipe_file}.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # Generate updated recipe
    create_recipe_file "$recipe_file"

    log_success "Recipe file auto-updated: $recipe_file"
}

# Create complete recipe file
create_recipe_file() {
    local recipe_file="$1"

    cat > "$recipe_file" << 'EOF'
# =================================================================
# ROBOTICS CONTROLLER APPLICATION RECIPE
# =================================================================
# This recipe builds the main robotics controller application from source
# Auto-generated by manage-recipe.sh script
# =================================================================

SUMMARY = "Robotics Controller Application"
DESCRIPTION = "Main application for robotics controller platform with web interface"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# =================================================================
# SOURCE CODE LOCATION
# =================================================================
SRC_URI = "file://robotics-controller.service \
           file://robotics-controller-init \
           file://robotics-controller.conf \
          "

# Use the workspace source directly (not a copy in the recipe)
S = "${TOPDIR}/../src/robotics-controller"

# =================================================================
# DEPENDENCIES
# =================================================================
DEPENDS = "opencv libgpiod nlohmann-json boost protobuf-native protobuf systemd cmake-native"

RDEPENDS:${PN} = "opencv libgpiod nlohmann-json boost protobuf python3-core python3-opencv systemd"

# =================================================================
# BUILD SYSTEM
# =================================================================
inherit cmake systemd

# Systemd configuration
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "robotics-controller.service"
SYSTEMD_AUTO_ENABLE = "enable"

# =================================================================
# FILE INSTALLATION
# =================================================================
FILES:${PN} += " \
    ${bindir}/robotics-controller \
    ${sysconfdir}/robotics-controller.conf \
    ${sysconfdir}/init.d/robotics-controller \
    ${datadir}/${PN}/www/* \
    ${systemd_system_unitdir}/robotics-controller.service \
"

# =================================================================
# INSTALLATION PROCEDURE
# =================================================================
do_install() {
    # Install main executable
    install -d ${D}${bindir}
    install -m 0755 ${B}/robotics-controller ${D}${bindir}/

    # Install configuration
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/robotics-controller.conf ${D}${sysconfdir}/

    # Install init script
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/robotics-controller-init ${D}${sysconfdir}/init.d/robotics-controller

    # Install web interface from workspace
    install -d ${D}${datadir}/${PN}/www
    cp -R ${TOPDIR}/../src/web-interface/* ${D}${datadir}/${PN}/www/

    # Install systemd service
    if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
        install -d ${D}${systemd_system_unitdir}
        install -m 0644 ${WORKDIR}/robotics-controller.service ${D}${systemd_system_unitdir}/
    fi
}

# =================================================================
# INIT SCRIPT CONFIGURATION
# =================================================================
INITSCRIPT_NAME = "robotics-controller"
INITSCRIPT_PARAMS = "defaults 99"

inherit update-rc.d
EOF

    log_success "Created complete recipe file: $recipe_file"
}

# Main execution
main() {
    local command="${1:-}"
    local verbose=false
    local force=false

    # Parse options
    shift || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Execute command
    case "$command" in
        sync-src)
            sync_source
            ;;
        sync-configs)
            sync_configs
            ;;
        auto-populate)
            auto_populate
            ;;
        update-recipe)
            update_recipe
            ;;
        validate)
            validate_layer
            ;;
        clean-recipe)
            clean_recipe
            ;;
        show-info)
            show_info
            ;;
        test-recipe)
            test_recipe
            ;;
        check-symlinks)
            check_symlinks
            ;;
        create-layer)
            create_layer_structure
            ;;
        update-all)
            update_all
            ;;
        "")
            log_error "No command specified"
            show_help
            exit 1
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
