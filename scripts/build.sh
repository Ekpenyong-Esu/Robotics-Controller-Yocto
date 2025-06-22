#!/bin/bash

# Yocto Robotics Controller Build Script
# Sets up the Yocto Project environment and manages the build process

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Configuration
YOCTO_VERSION="scarthgap"
POKY_URL="git://git.yoctoproject.org/poky"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
META_DIR="${PROJECT_ROOT}/meta-robotics"

# Constants
readonly MIN_DISK_SPACE_GB=50
readonly MIN_DISK_SPACE_KB=$((MIN_DISK_SPACE_GB * 1024 * 1024))

# Default configuration
DEFAULT_MACHINE="beaglebone-robotics"
VERBOSE=false
CLEAN_BUILD=false

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
Usage: $0 [OPTIONS]

Build script for Embedded Robotics Controller with Yocto Project

OPTIONS:
    -h, --help              Show this help message
    -m, --machine MACHINE   Use specific machine configuration (default: ${DEFAULT_MACHINE})
    -C, --clean             Perform clean build (removes existing build directory)
    -v, --verbose           Enable verbose output
    -j, --jobs N            Number of parallel build jobs (default: auto-detect)
    -q, --qemu              Build for QEMU testing

EXAMPLES:
    $0                              # Standard build with default machine
    $0 --clean                      # Clean build
    $0 --machine raspberrypi3       # Build for Raspberry Pi 3
    $0 --machine rpi4-robotics      # Build for Raspberry Pi 4
    $0 --qemu                       # Build for QEMU testing
    $0 --verbose --jobs 8           # Verbose build with 8 parallel jobs

MACHINES:
    beaglebone-robotics             BeagleBone Black configuration
    raspberrypi3                    Raspberry Pi 3 configuration
    rpi4-robotics                   Raspberry Pi 4 configuration
    qemu-robotics                   QEMU for testing

EOF
}

# Check system dependencies
check_dependencies() {
    log_info "Checking system dependencies for Yocto..."

    local deps=("git" "python3" "chrpath" "diffstat" "gawk" "texinfo" "unzip" "gcc" "make" "chrpath" "socat" "cpio" "xz-utils" "rsync")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        case "$dep" in
                "build-essential"|"xz-utils"|"libegl1-mesa"|"texinfo")
                    if ! dpkg -l "$dep" &>/dev/null; then
                        missing_deps+=("$dep")
                    fi
                    ;;
                "gcc")
                    if ! command -v gcc &>/dev/null; then
                        missing_deps+=("build-essential")
                    fi
                    ;;
                *)
                    if ! command -v "$dep" &> /dev/null; then
                        missing_deps+=("$dep")
                    fi
                    ;;
            esac
    done

    # Check for Python modules
    local py_modules=("pexpect" "git" "jinja2" "subunit")
    for module in "${py_modules[@]}"; do
        if ! python3 -c "import $module" &>/dev/null; then
            missing_deps+=("python3-$module")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install them with: sudo apt update && sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev xterm python3-subunit mesa-common-dev zstd liblz4-tool rsync"
        exit 1
    fi

    # Check for minimum disk space
    local available_space
    available_space=$(df "${PROJECT_ROOT}" | tail -1 | awk '{print $4}')

    if [ "$available_space" -lt "$MIN_DISK_SPACE_KB" ]; then
        log_warn "Low disk space detected. At least ${MIN_DISK_SPACE_GB}GB recommended for Yocto builds."
    fi

    log_success "All dependencies satisfied"
}

# Setup Poky (base Yocto Project)
setup_yocto() {
    log_info "Setting up Yocto Project environment..."

    mkdir -p "$BUILD_DIR"

    # Clone or update poky if not present
    if [ ! -d "${BUILD_DIR}/poky" ]; then
        log_info "Cloning Yocto/Poky repository..."
        git clone -b "${YOCTO_VERSION}" git://git.yoctoproject.org/poky "${BUILD_DIR}/poky" || {
            log_error "Failed to clone Poky repository"
            exit 1
        }
    else
        log_info "Poky repository already exists"
        cd "${BUILD_DIR}/poky"
        git pull || log_warn "Could not update Poky repository"
        cd "${PROJECT_ROOT}"
    fi

    # Clone or update meta-openembedded if not present
    if [ ! -d "${BUILD_DIR}/meta-openembedded" ]; then
        log_info "Cloning meta-openembedded repository..."
        git clone -b "${YOCTO_VERSION}" git://git.openembedded.org/meta-openembedded "${BUILD_DIR}/meta-openembedded" || {
            log_warn "Failed to clone meta-openembedded repository, continuing anyway"
        }
    else
        cd "${BUILD_DIR}/meta-openembedded"
        git pull || log_warn "Could not update meta-openembedded repository"
        cd "${PROJECT_ROOT}"
    fi
}

# Setup robotics layers and configurations
setup_layers() {
    log_info "Setting up robotics layer..."

    # Auto-populate entire meta-robotics layer
    local manage_recipe_script="${PROJECT_ROOT}/scripts/manage-recipe.sh"
    if [ -x "$manage_recipe_script" ]; then
        log_info "Auto-populating meta-robotics layer (industrial automation)..."
        "$manage_recipe_script" auto-populate --force

        log_info "Final validation of meta-robotics layer..."
        "$manage_recipe_script" validate
    else
        log_error "Recipe management script not found - cannot auto-populate meta-robotics layer"
        exit 1
    fi

    # Copy our meta-robotics layer to build dir for consistent access
    if [ ! -d "${BUILD_DIR}/meta-robotics" ]; then
        log_info "Copying meta-robotics layer to build directory..."
        cp -r "${PROJECT_ROOT}/meta-robotics" "${BUILD_DIR}/meta-robotics"
    else
        log_info "Updating meta-robotics layer in build directory..."
        rsync -av --delete "${PROJECT_ROOT}/meta-robotics/" "${BUILD_DIR}/meta-robotics/"
    fi

    # Create build conf directory if it doesn't exist
    mkdir -p "${BUILD_DIR}/conf"

    # Setup Raspberry Pi layer if needed
    local rpi_layer_path="${BUILD_DIR}/meta-raspberrypi"
    if [ ! -d "$rpi_layer_path" ] && [[ "$MACHINE" == "raspberrypi3" || "$MACHINE" == "rpi4-robotics" ]]; then
        log_info "Cloning meta-raspberrypi layer..."
        git clone -b "${YOCTO_VERSION}" git://git.yoctoproject.org/meta-raspberrypi "$rpi_layer_path" || {
            log_warn "Failed to clone meta-raspberrypi repository, continuing anyway"
        }
    fi

    # Create local.conf if it doesn't exist
    if [ ! -f "${BUILD_DIR}/conf/local.conf" ]; then
        log_info "Creating local.conf from template..."

        # Determine machine-specific template directory
        local machine_config_dir=""
        case "${MACHINE:-$DEFAULT_MACHINE}" in
            "raspberrypi3")
                machine_config_dir="rpi3-config"
                ;;
            "rpi4-robotics")
                machine_config_dir="rpi4-config"
                ;;
            "beaglebone-robotics")
                machine_config_dir="beaglebone-config"
                ;;
            "qemu-robotics")
                machine_config_dir="qemu-config"
                ;;
        esac

        # Try machine-specific template first, then fall back to generic
        local template_used=false
        if [ -n "$machine_config_dir" ] && [ -f "${PROJECT_ROOT}/meta-robotics/conf/templates/${machine_config_dir}/local.conf.sample" ]; then
            log_info "Using machine-specific template: ${machine_config_dir}/local.conf.sample"
            cp "${PROJECT_ROOT}/meta-robotics/conf/templates/${machine_config_dir}/local.conf.sample" "${BUILD_DIR}/conf/local.conf"
            template_used=true
        elif [ -f "${PROJECT_ROOT}/meta-robotics/conf/templates/local.conf.sample" ]; then
            log_info "Using generic template: local.conf.sample"
            cp "${PROJECT_ROOT}/meta-robotics/conf/templates/local.conf.sample" "${BUILD_DIR}/conf/local.conf"
            template_used=true
        fi

        # Create default configuration if no template found
        if [ "$template_used" = false ]; then
            log_info "No template found, creating default local.conf"
            cat > "${BUILD_DIR}/conf/local.conf" << EOF
MACHINE ?= "${MACHINE:-beaglebone-robotics}"
DISTRO ?= "poky"
PACKAGE_CLASSES ?= "package_rpm"
EXTRA_IMAGE_FEATURES ?= "debug-tweaks"
USER_CLASSES ?= "buildstats"
PATCHRESOLVE = "noop"
BB_DISKMON_DIRS ??= "\${TMPDIR} \${DL_DIR} \${SSTATE_DIR} \${WORKDIR}"
CONF_VERSION = "2"
EOF
        fi
    fi

    # Create bblayers.conf if it doesn't exist
    if [ ! -f "${BUILD_DIR}/conf/bblayers.conf" ]; then
        log_info "Creating bblayers.conf from template..."

        # Determine machine-specific template directory (reuse from local.conf logic)
        local machine_config_dir=""
        case "${MACHINE:-$DEFAULT_MACHINE}" in
            "raspberrypi3")
                machine_config_dir="rpi3-config"
                ;;
            "rpi4-robotics")
                machine_config_dir="rpi4-config"
                ;;
            "beaglebone-robotics")
                machine_config_dir="beaglebone-config"
                ;;
            "qemu-robotics")
                machine_config_dir="qemu-config"
                ;;
        esac

        # Try machine-specific template first, then fall back to generic
        local template_used=false
        if [ -n "$machine_config_dir" ] && [ -f "${PROJECT_ROOT}/meta-robotics/conf/templates/${machine_config_dir}/bblayers.conf.sample" ]; then
            log_info "Using machine-specific template: ${machine_config_dir}/bblayers.conf.sample"
            cp "${PROJECT_ROOT}/meta-robotics/conf/templates/${machine_config_dir}/bblayers.conf.sample" "${BUILD_DIR}/conf/bblayers.conf"
            template_used=true
        elif [ -f "${PROJECT_ROOT}/meta-robotics/conf/templates/bblayers.conf.sample" ]; then
            log_info "Using generic template: bblayers.conf.sample"
            cp "${PROJECT_ROOT}/meta-robotics/conf/templates/bblayers.conf.sample" "${BUILD_DIR}/conf/bblayers.conf"
            template_used=true
        fi

        # Create default configuration if no template found
        if [ "$template_used" = false ]; then
            log_info "No template found, creating default bblayers.conf"
            cat > "${BUILD_DIR}/conf/bblayers.conf" << EOF
# POKY_BBLAYERS_CONF_VERSION is increased each time build/conf/bblayers.conf
# changes incompatibly
POKY_BBLAYERS_CONF_VERSION = "2"

BBPATH = "\${TOPDIR}"
BBFILES ?= ""

BBLAYERS ?= " \\
  \${TOPDIR}/../poky/meta \\
  \${TOPDIR}/../poky/meta-poky \\
  \${TOPDIR}/../poky/meta-yocto-bsp \\
  \${TOPDIR}/../meta-openembedded/meta-oe \\
  \${TOPDIR}/../meta-openembedded/meta-python \\
  \${TOPDIR}/../meta-openembedded/meta-networking \\
  \${TOPDIR}/../meta-openembedded/meta-multimedia \\
  \${TOPDIR}/../meta-robotics \\
  "
EOF
        fi
    fi
}
# Configure Yocto for build
configure_build() {
    local machine_name="${MACHINE:-$DEFAULT_MACHINE}"
    log_info "Configuring Yocto build for ${machine_name}..."

    # Update machine in local.conf
    sed -i "s/^MACHINE ?=.*/MACHINE ?= \"${machine_name}\"/" "${BUILD_DIR}/conf/local.conf"

    # If QEMU was selected, override with qemu machine
    if [ "$USE_QEMU" = true ]; then
        log_info "Configuring for QEMU testing..."
        sed -i "s/^MACHINE ?=.*/MACHINE ?= \"qemu-robotics\"/" "${BUILD_DIR}/conf/local.conf"

        # Add QEMU options for better performance
        if ! grep -q "PACKAGECONFIG:append:pn-qemu" "${BUILD_DIR}/conf/local.conf"; then
            echo 'PACKAGECONFIG:append:pn-qemu-native = " sdl"' >> "${BUILD_DIR}/conf/local.conf"
            echo 'PACKAGECONFIG:append:pn-nativesdk-qemu = " sdl"' >> "${BUILD_DIR}/conf/local.conf"
        fi
    fi

    log_success "Build configuration updated"
}

# Initialize Yocto build environment
initialize_build() {
    log_info "Initializing Yocto build environment..."

    # Source the setup script to set up environment
    cd "${BUILD_DIR}/poky"

    # Generate setup script for later use
    cat > "${BUILD_DIR}/setup-environment" << 'EOF'
#!/bin/bash
. poky/oe-init-build-env build
EOF
    chmod +x "${BUILD_DIR}/setup-environment"

    # Show success message but note we're not executing the script in this shell
    # as it would change the current shell environment
    log_success "Build environment setup script created"
    log_info "To start the build, run: cd ${BUILD_DIR} && source setup-environment"
    log_info "Then run: bitbake robotics-controller-image"

    # Show message about QEMU if selected
    if [ "$USE_QEMU" = true ]; then
        log_info "For QEMU testing after build: runqemu qemu-robotics"
    fi
}

# Build the system
build_system() {
    log_info "Starting build process..."

    # Set the number of parallel jobs
    if [ -z "$JOBS" ]; then
        # Auto-detect number of CPU cores
        JOBS=$(nproc)
        log_info "Auto-detected $JOBS CPU cores for parallel build"
    else
        log_info "Using $JOBS parallel jobs"
    fi

    # Actually run the build
    log_info "Starting the build process..."
    cd "${BUILD_DIR}"
    source setup-environment

    # Execute bitbake with proper error handling
    if [ -n "${JOBS:-}" ]; then
        if PARALLEL_MAKE="-j ${JOBS}" bitbake robotics-controller-image; then
            log_success "Build completed successfully!"
        else
            log_error "Build failed!"
            exit 1
        fi
    else
        if bitbake robotics-controller-image; then
            log_success "Build completed successfully!"
        else
            log_error "Build failed!"
            exit 1
        fi
    fi

    if [ "$VERBOSE" = true ]; then
        log_info "Verbose mode enabled. Add 'BB_VERBOSE_LOGS=yes' for more detailed build logs."
    fi
}

# Create convenience output directory
create_output_directory() {
    log_info "Creating output directory with build artifacts..."

    # Create output directory and copy deploy images
    local deploy_dir="${BUILD_DIR}/tmp/deploy/images"
    local output_dir="${PROJECT_ROOT}/output"

    if [ -d "$deploy_dir" ]; then
        mkdir -p "$output_dir"
        log_info "Copying build artifacts to output directory..."
        cp -r "$deploy_dir"/* "$output_dir/" 2>/dev/null || true
        log_success "Build artifacts copied to: ${output_dir}"
    else
        log_warn "Deploy directory not found yet, skipping output directory creation"
        log_info "After building, output images will be in: ${deploy_dir}"
    fi
}

# Show build summary
show_summary() {
    log_info "Yocto Project Setup Summary:"
    echo "================================"

    echo "Project directory: ${PROJECT_ROOT}"
    echo "Build directory: ${BUILD_DIR}"
    echo ""

    echo "Machine configuration: ${MACHINE:-$DEFAULT_MACHINE}"
    if [ "$USE_QEMU" = true ]; then
        echo "QEMU testing: Enabled"
    else
        echo "QEMU testing: Disabled"
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Initialize build environment:"
    echo "     cd ${BUILD_DIR} && source setup-environment"
    echo ""
    echo "  2. Build the image:"
    echo "     bitbake robotics-controller-image"
    echo ""
    echo "  3. Flash the image when built:"
    echo "     ./scripts/flash.sh /dev/sdX"
    echo ""

    if [ "$USE_QEMU" = true ]; then
        echo "  4. For QEMU testing:"
        echo "     runqemu qemu-robotics"
    else
        echo "  4. Deploy to hardware and boot"
    fi
}

# Main execution
main() {
    log_info "Starting Embedded Robotics Controller Setup with Yocto"
    log_info "Project: ${PROJECT_ROOT}"

    # Create build directory
    mkdir -p "$BUILD_DIR"

    # Check dependencies
    check_dependencies

    # Clean build if requested
    if [ "$CLEAN_BUILD" = true ]; then
        log_info "Performing clean build..."
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
    fi

    # Setup Yocto environment
    setup_yocto
    setup_layers
    configure_build
    initialize_build

    # Build the system
    build_system

    # Create output directory with artifacts
    create_output_directory

    # Show summary
    show_summary

    log_success "Build process completed!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -m|--machine)
            MACHINE="$2"
            shift 2
            ;;
        -C|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -q|--qemu)
            USE_QEMU=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main
