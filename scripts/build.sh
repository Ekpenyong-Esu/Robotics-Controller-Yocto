#!/bin/bash

# Yocto Robotics Controller Build Script
# Sets up the Yocto Project environment and manages the build process

#set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Configuration
YOCTO_VERSION="kirkstone"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

# Constants
readonly MIN_DISK_SPACE_GB=50
readonly MIN_DISK_SPACE_KB=$((MIN_DISK_SPACE_GB * 1024 * 1024))

# Default configuration

DEFAULT_MACHINE="beaglebone-robotics"


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


    local deps=(
        "git" "python3" "chrpath" "diffstat" "gawk" "texinfo" "unzip" "gcc" "make" "chrpath" "socat" "cpio" "xz-utils" "rsync"
    )
    local extended_deps=(
        "libffi-dev" "libssl-dev" "zlib1g-dev" "libbz2-dev" "libreadline-dev" "libsqlite3-dev" "libncurses5-dev" "libgdbm-dev" "liblzma-dev" "tk-dev" "uuid-dev"
    )
    local missing_deps=()
    local missing_ext=()

    for dep in "${deps[@]}"; do
        if ! dpkg -s "$dep" &>/dev/null && ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    for dep in "${extended_deps[@]}"; do
        if ! dpkg -s "$dep" &>/dev/null; then
            missing_ext+=("$dep")
        fi
    done

    # Check for Python modules
    local py_modules=("pexpect" "git" "jinja2" "subunit")
    for module in "${py_modules[@]}"; do
        if ! python3 -c "import $module" &>/dev/null; then
            missing_deps+=("python3-$module")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing basic dependencies: ${missing_deps[*]}"
        log_info "Install them with: sudo apt update && sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev xterm python3-subunit mesa-common-dev zstd liblz4-tool rsync"
        exit 1
    fi

    if [ ${#missing_ext[@]} -ne 0 ]; then
        log_warn "Some additional host libraries required for Python/Perl native builds are missing: ${missing_ext[*]}"
        log_warn "These are needed for modules like _ctypes, ssl, bz2, lzma, sqlite3, readline, etc."
        log_info "Install them with: sudo apt install -y ${missing_ext[*]}"
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

    # Check for submodules (poky, meta-openembedded)
    if [ ! -d "${PROJECT_ROOT}/poky" ] || [ ! -d "${PROJECT_ROOT}/meta-openembedded" ]; then
        log_error "Required submodules (poky, meta-openembedded) are missing."
        log_info "Please run: git submodule update --init --recursive"
        exit 1
    fi

    log_success "All required submodules are present."
}

# Setup robotics layers and configurations
setup_layers() {
    log_info "Setting up robotics layer..."

    # Auto-populate entire meta-robotics layer only if it does not exist
    local manage_recipe_script="${PROJECT_ROOT}/scripts/manage-recipe.sh"
    if [ ! -d "${PROJECT_ROOT}/meta-robotics" ]; then
        if [ -x "$manage_recipe_script" ]; then
            log_info "Auto-populating meta-robotics layer (industrial automation)..."
            "$manage_recipe_script" auto-populate --force

            log_info "Final validation of meta-robotics layer..."
            "$manage_recipe_script" validate
        else
            log_error "Recipe management script not found - cannot auto-populate meta-robotics layer"
            exit 1
        fi
    else
        log_info "meta-robotics layer already exists, skipping auto-populate."
    fi

    # Always sync meta-robotics if it exists in project root
    if [ -d "${PROJECT_ROOT}/meta-robotics" ]; then
        log_info "Synchronizing meta-robotics layer with build directory (always, minimal and modular)..."
        rsync -av --delete --exclude='.git' --exclude='*.swp' --exclude='*.bak' "${PROJECT_ROOT}/meta-robotics/" "${BUILD_DIR}/meta-robotics/"
    else
        log_warn "meta-robotics layer does not exist in project root, skipping sync."
    fi

    # Copy only the machine-specific conf template to build/conf
    mkdir -p "${BUILD_DIR}/conf"
    local machine_config_dir=""
    case "${MACHINE:-$DEFAULT_MACHINE}" in
        "raspberrypi3")
            machine_config_dir="rpi3-config";;
        "rpi4-robotics")
            machine_config_dir="rpi4-config";;
        "beaglebone-robotics")
            machine_config_dir="beaglebone-config";;
        "qemu-robotics")
            machine_config_dir="qemu-config";;
    esac
    if [ -n "$machine_config_dir" ] && [ -d "${PROJECT_ROOT}/meta-robotics/conf/templates/${machine_config_dir}" ]; then
        log_info "Copying conf files for $MACHINE from template: ${machine_config_dir}"
        cp -f "${PROJECT_ROOT}/meta-robotics/conf/templates/${machine_config_dir}/local.conf" "${BUILD_DIR}/conf/local.conf"
        if [ -f "${PROJECT_ROOT}/meta-robotics/conf/templates/${machine_config_dir}/bblayers.conf" ]; then
            cp -f "${PROJECT_ROOT}/meta-robotics/conf/templates/${machine_config_dir}/bblayers.conf" "${BUILD_DIR}/conf/bblayers.conf"
        fi
    else
        log_info "No machine-specific conf template found, using generic if available."
        if [ -f "${PROJECT_ROOT}/meta-robotics/conf/templates/local.conf" ]; then
            cp -f "${PROJECT_ROOT}/meta-robotics/conf/templates/local.conf" "${BUILD_DIR}/conf/local.conf"
        fi
        if [ -f "${PROJECT_ROOT}/meta-robotics/conf/templates/bblayers.conf" ]; then
            cp -f "${PROJECT_ROOT}/meta-robotics/conf/templates/bblayers.conf" "${BUILD_DIR}/conf/bblayers.conf"
        fi
    fi

    # Check for meta-raspberrypi submodule if needed
    if [[ "$MACHINE" == "raspberrypi3" || "$MACHINE" == "rpi4-robotics" ]]; then
        if [ ! -d "${PROJECT_ROOT}/meta-raspberrypi" ]; then
            log_error "Required submodule 'meta-raspberrypi' is missing."
            log_info "Please run: git submodule update --init --recursive"
            exit 1
        fi
        # Optionally sync/copy meta-raspberrypi to build dir if needed by your workflow
        if [ ! -d "${BUILD_DIR}/meta-raspberrypi" ]; then
            log_info "Copying meta-raspberrypi layer to build directory..."
            cp -r "${PROJECT_ROOT}/meta-raspberrypi" "${BUILD_DIR}/meta-raspberrypi"
        else
            log_info "Updating meta-raspberrypi layer in build directory..."
            rsync -av --delete "${PROJECT_ROOT}/meta-raspberrypi/" "${BUILD_DIR}/meta-raspberrypi/"
        fi
    fi
}

# Initialize Yocto build environment
initialize_build() {
    log_info "Initializing Yocto build environment..."

    # Generate setup script for later use
    cat > "${BUILD_DIR}/setup-environment" << 'EOF'
#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")"
source ../poky/oe-init-build-env .
EOF
    chmod +x "${BUILD_DIR}/setup-environment"

    log_success "Build environment setup script created"
}

# Build the system
build_system() {
    log_info "Starting build process..."

    # Set the number of parallel jobs
    if [ -z "$JOBS" ]; then
        # Auto-detect number of CPU cores and use half to prevent system overload
        local total_cores
        total_cores=$(nproc)
        JOBS=$((total_cores / 2))
        # Ensure at least 1 job
        if [ "$JOBS" -lt 1 ]; then
            JOBS=1
        fi
        log_info "Auto-detected $total_cores CPU cores, using $JOBS jobs (half) for parallel build"
    else
        log_info "Using $JOBS parallel jobs"
    fi

    # Determine which image to build
    local image_name="robotics-controller-image"
    if [ "$USE_QEMU" = true ]; then
        image_name="robotics-qemu-image"
        log_info "Building QEMU-specific image: $image_name"
    else
        log_info "Building hardware image: $image_name"
    fi

    # Actually run the build
    log_info "Starting the build process..."

    # Change to build directory and source the Yocto environment
    (
        set -e
        cd "${BUILD_DIR}"
        source "${PROJECT_ROOT}/poky/oe-init-build-env" .

        # Execute bitbake with proper error handling
        if [ -n "${JOBS:-}" ]; then
            if PARALLEL_MAKE="-j ${JOBS}" bitbake "$image_name"; then
                log_success "Build completed successfully!"
            else
                log_error "Build failed!"
                exit 1
            fi
        else
            if bitbake "$image_name"; then
                log_success "Build completed successfully!"
            else
                log_error "Build failed!"
                exit 1
            fi
        fi
    )

    if [ "$VERBOSE" = true ]; then
        log_info "Verbose mode enabled. Add 'BB_VERBOSE_LOGS=yes' for more detailed build logs."
    fi
    log_info "Build process finished. Artifacts will be available in: ${BUILD_DIR}/tmp-glibc/deploy/images/${MACHINE}"
}

# Create convenience output directory
create_output_directory() {
    log_info "Creating output directory with build artifacts..."

    # Create output directory and copy deploy images
    local deploy_dir="${BUILD_DIR}/tmp-glibc/deploy/images/${MACHINE}"
    local output_dir="${PROJECT_ROOT}/output"

    log_info "Checking deploy directory: ${deploy_dir}"

    if [ -d "$deploy_dir" ]; then
        # Clean and recreate output directory for fresh copy
        if [ -d "$output_dir" ]; then
            log_info "Cleaning existing output directory"
            rm -rf "$output_dir"
        fi
        
        mkdir -p "$output_dir"
        log_info "Copying build artifacts from: ${deploy_dir}"

        # Copy kernel image
        if [ -f "${deploy_dir}/Image" ]; then
            cp "${deploy_dir}/Image" "${output_dir}/kernel"
            log_info "Copied kernel image: Image -> kernel"
        fi

        # Copy root filesystem (ext4) - find the correct image file
        local rootfs_ext4
        if [ -f "${deploy_dir}/robotics-controller-image-${MACHINE}.ext4" ]; then
            rootfs_ext4="${deploy_dir}/robotics-controller-image-${MACHINE}.ext4"
        elif [ -f "${deploy_dir}/robotics-qemu-image-${MACHINE}.ext4" ]; then
            rootfs_ext4="${deploy_dir}/robotics-qemu-image-${MACHINE}.ext4"
        else
            rootfs_ext4=$(find "${deploy_dir}" -name "*.rootfs.ext4" | head -1)
        fi
        
        if [ -n "$rootfs_ext4" ] && [ -f "$rootfs_ext4" ]; then
            cp "$rootfs_ext4" "${output_dir}/rootfs.ext4"
            # Also create properly named symlink for easy access
            local image_name=$(basename "$rootfs_ext4")
            ln -sf "rootfs.ext4" "${output_dir}/${image_name}"
            log_info "Copied root filesystem: $(basename "$rootfs_ext4") -> rootfs.ext4"
        fi

        # Copy root filesystem archive
        local rootfs_tar
        if [ -f "${deploy_dir}/robotics-controller-image-${MACHINE}.tar.bz2" ]; then
            rootfs_tar="${deploy_dir}/robotics-controller-image-${MACHINE}.tar.bz2"
        elif [ -f "${deploy_dir}/robotics-qemu-image-${MACHINE}.tar.bz2" ]; then
            rootfs_tar="${deploy_dir}/robotics-qemu-image-${MACHINE}.tar.bz2"
        else
            rootfs_tar=$(find "${deploy_dir}" -name "*.rootfs.tar.bz2" | head -1)
        fi
        
        if [ -n "$rootfs_tar" ] && [ -f "$rootfs_tar" ]; then
            cp "$rootfs_tar" "${output_dir}/rootfs.tar.bz2"
            log_info "Copied root filesystem archive: $(basename "$rootfs_tar") -> rootfs.tar.bz2"
        fi

        # Copy QEMU config
        local qemu_conf=$(find "${deploy_dir}" -name "*.qemuboot.conf" | head -1)
        if [ -n "$qemu_conf" ]; then
            cp "$qemu_conf" "${output_dir}/qemuboot.conf"
            log_info "Copied QEMU config: $(basename "$qemu_conf") -> qemuboot.conf"
        fi

        # Create machine-specific output directory with latest build only
        mkdir -p "${output_dir}/${MACHINE}"
        
        # Copy only the latest build files (no accumulation)
        for file in "${deploy_dir}"/*; do
            if [ -f "$file" ]; then
                cp "$file" "${output_dir}/${MACHINE}/"
            fi
        done

        # Create helpful scripts in output directory
        create_output_scripts "$output_dir"

        log_success "Build artifacts copied to: ${output_dir}"
        log_info "Machine-specific files also available in: ${output_dir}/${MACHINE}"
        log_info "Use scripts/test-qemu-login.sh to test the QEMU image"
    else
        log_warn "Deploy directory not found: ${deploy_dir}"
        log_info "After building, output images will be in: ${deploy_dir}"
    fi
}

# Create helpful scripts in output directory
create_output_scripts() {
    local output_dir="$1"
    
    # Create QEMU launch script
    cat > "${output_dir}/launch-qemu.sh" << 'EOF'
#!/bin/bash
# Quick QEMU launch script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="${SCRIPT_DIR}/rootfs.ext4"

if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: Image file not found: $IMAGE_FILE"
    exit 1
fi

echo "Launching QEMU with image: $IMAGE_FILE"
echo "Login: root/root or root/(empty password)"
echo "Press Ctrl+A, then X to exit QEMU"
echo ""

# Try runqemu first, fallback to direct qemu command
if command -v runqemu >/dev/null 2>&1; then
    cd "$(dirname "$SCRIPT_DIR")/build"
    runqemu qemu-robotics nographic
else
    qemu-system-aarch64 \
        -machine virt \
        -cpu cortex-a57 \
        -m 1024 \
        -nographic \
        -kernel "${SCRIPT_DIR}/kernel" \
        -drive file="${IMAGE_FILE}",format=raw,id=hd0 \
        -netdev user,id=net0 \
        -device virtio-net-device,netdev=net0 \
        -append "root=/dev/vda rw console=ttyAMA0"
fi
EOF
    chmod +x "${output_dir}/launch-qemu.sh"
    
    # Create build info file
    cat > "${output_dir}/BUILD_INFO.txt" << EOF
Build Information
=================
Build Date: $(date)
Machine: ${MACHINE}
Build Directory: ${BUILD_DIR}
Deploy Directory: ${BUILD_DIR}/tmp-glibc/deploy/images/${MACHINE}

Files:
- kernel: Linux kernel image
- rootfs.ext4: Root filesystem (ext4 format)
- rootfs.tar.bz2: Root filesystem archive
- qemuboot.conf: QEMU boot configuration
- ${MACHINE}/: Complete machine-specific build artifacts

Usage:
- Launch QEMU: ./launch-qemu.sh
- Test login: ../scripts/test-qemu-login.sh
- Build logs: ${BUILD_DIR}/tmp-glibc/log/
EOF

    log_info "Created launch script: ${output_dir}/launch-qemu.sh"
    log_info "Created build info: ${output_dir}/BUILD_INFO.txt"
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

    # Ensure git submodules are initialized and updated FIRST
    log_info "Initializing and updating git submodules..."
    git submodule init
    git submodule sync
    git submodule update --recursive

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

# Ensure MACHINE is set to qemu-robotics before any template selection if --qemu is used
if [ "$USE_QEMU" = true ]; then
    MACHINE="qemu-robotics"
fi

# Set default MACHINE if not specified
if [ -z "$MACHINE" ]; then
    MACHINE="$DEFAULT_MACHINE"
fi

# Run main function
main
