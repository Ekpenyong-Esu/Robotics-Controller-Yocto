#!/bin/bash

# Run Script for Robotics Controller
# Runs the system in QEMU for testing or connects to hardware with Yocto

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
DEPLOY_DIR="${BUILD_DIR}/tmp/deploy/images"

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
Usage: $0 [OPTIONS] [MODE]

Run or connect to the Embedded Robotics Controller

MODES:
    qemu                Run system in QEMU emulator (default)
    raspberry           Connect to Raspberry Pi hardware via SSH/serial
    beaglebone          Connect to BeagleBone hardware via serial/SSH
    hardware            Connect to hardware via serial console (generic)
    ssh                 Connect via SSH (requires network setup)
    monitor             Monitor system logs and status

OPTIONS:
    -h, --help          Show this help message
    -p, --port PORT     Serial port for hardware connection (default: /dev/ttyUSB0)
    -b, --baud RATE     Baud rate for serial connection (default: 115200)
    -i, --ip IP         IP address for SSH connection
    -u, --user USER     Username for SSH (default: root)
    -m, --memory SIZE   Memory for QEMU (default: 512M)
    -n, --network       Enable network in QEMU
    -g, --graphics      Enable graphics in QEMU
    -d, --debug         Enable debug output

EXAMPLES:
    $0                                    # Run in QEMU (generic)
    $0 raspberry                          # Connect to Raspberry Pi hardware
    $0 beaglebone                         # Connect to BeagleBone hardware
    $0 qemu --network --memory 1G        # QEMU with network and more memory
    $0 hardware --port /dev/ttyUSB1      # Connect to hardware on different port
    $0 ssh --ip 192.168.1.100           # SSH to robot
    $0 monitor                           # Monitor system status

QEMU CONTROLS:
    Ctrl+A, X          Exit QEMU
    Ctrl+A, C          QEMU monitor console
    Ctrl+A, H          Help

HARDWARE CONNECTION:
    Requires FTDI USB-to-serial adapter connected to BeagleBone UART0
    Default: /dev/ttyUSB0 at 115200 baud

EOF
}

check_yocto() {
    log_info "Checking Yocto environment..."

    # Check for required submodules (poky, meta-openembedded)
    local missing_submodules=()
    if [ ! -d "${PROJECT_ROOT}/poky" ]; then
        missing_submodules+=("poky")
    fi
    if [ ! -d "${PROJECT_ROOT}/meta-openembedded" ]; then
        missing_submodules+=("meta-openembedded")
    fi
    if [ ${#missing_submodules[@]} -ne 0 ]; then
        log_error "Required submodules missing: ${missing_submodules[*]}"
        log_info "Run: git submodule update --init --recursive in the project root."
        exit 1
    fi

    if [ ! -f "${BUILD_DIR}/setup-environment" ]; then
        log_error "Build environment not initialized. Run './scripts/build.sh' first"
        exit 1
    fi
}

check_qemu() {
    if ! command -v runqemu &> /dev/null; then
        log_info "Looking for Yocto's runqemu..."

        if [ -f "${BUILD_DIR}/tmp/sysroots-components/x86_64/qemu-native/usr/bin/runqemu" ]; then
            log_success "Found runqemu in Yocto build environment"
        else
            log_error "QEMU not found in Yocto build"
            log_info "Build your Yocto image first with: bitbake robotics-controller-image"
            exit 1
        fi
    fi
}

check_serial_tools() {
    local tools=("minicom" "screen" "picocom")
    local available_tool=""

    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            available_tool="$tool"
            break
        fi
    done

    if [ -z "$available_tool" ]; then
        log_error "No serial terminal found"
        log_info "Install one of: ${tools[*]}"
        log_info "Example: sudo apt install minicom"
        exit 1
    fi

    echo "$available_tool"
}

run_qemu() {
    local memory="$1"
    local enable_network="$2"
    local enable_graphics="$3"
    local debug="$4"
    local target_machine="$5"

    # Set machine based on target
    local machine="qemu-robotics"
    case "$target_machine" in
        raspberry)
            machine="raspberrypi3"
            log_info "Starting Raspberry Pi 3 emulation with Yocto..."
            ;;
        beaglebone)
            machine="beaglebone-robotics"
            log_info "Starting BeagleBone emulation with Yocto..."
            ;;
        *)
            log_info "Starting QEMU emulation with Yocto..."
            ;;
    esac

    # Check Yocto environment
    check_yocto

    # Check if build is completed - look in both possible build directories
    local deploy_dir=""
    if [ -d "${BUILD_DIR}/build/tmp/deploy/images" ]; then
        deploy_dir="${BUILD_DIR}/build/tmp/deploy/images"
    elif [ -d "${BUILD_DIR}/tmp/deploy/images" ]; then
        deploy_dir="${BUILD_DIR}/tmp/deploy/images"
    else
        log_error "No images found in the build directory"
        log_info "Build your Yocto image first with:"
        log_info "  ./scripts/build.sh --qemu"
        exit 1
    fi

    # Check if machine-specific images exist
    local machine_deploy_dir="$deploy_dir/$machine"
    if [ ! -d "$machine_deploy_dir" ]; then
        log_error "No images found for machine: $machine"
        log_info "Available machines:"
        ls -la "$deploy_dir/" 2>/dev/null || echo "No machine directories found"
        log_info ""
        log_info "Build the image for your target machine:"
        log_info "  ./scripts/build.sh --qemu"
        exit 1
    fi

    log_info "Setting up QEMU environment..."

    # Change to the correct build directory
    local build_subdir="${BUILD_DIR}"
    if [ -d "${BUILD_DIR}/build" ]; then
        build_subdir="${BUILD_DIR}/build"
    fi

    cd "$build_subdir"

    # Build QEMU command options
    local qemu_opts=""

    # Add network if requested
    if [ "$enable_network" = "true" ]; then
        qemu_opts="$qemu_opts slirp"
        log_info "Network enabled - SSH and web ports will be forwarded"
    fi

    # Add graphics if requested
    if [ "$enable_graphics" = "false" ]; then
        qemu_opts="$qemu_opts nographic"
        log_info "Display: console mode"
    else
        log_info "Display: graphics mode"
    fi

    # Add memory settings
    if [ -n "$memory" ]; then
        qemu_opts="$qemu_opts qemuparams=\"-m $memory\""
        log_info "Memory set to $memory"
    fi

    # Add debug if requested
    if [ "$debug" = "true" ]; then
        qemu_opts="$qemu_opts qemuparams=\"-d guest_errors,unimp\""
        log_info "Debug mode enabled"
    fi

    log_info "Starting QEMU emulation for: $machine"
    log_info ""
    log_info "Control commands:"
    log_info "  Ctrl+A, X to quit"
    log_info "  Ctrl+A, C for QEMU console"
    log_info ""
    log_success "Launching virtual machine..."

    # Source environment and run QEMU directly
    source ../poky/oe-init-build-env > /dev/null
    eval "exec runqemu $machine $qemu_opts"
}

connect_hardware() {
    local serial_port="$1"
    local baud_rate="$2"

    log_info "Connecting to hardware..."

    # Check if device exists
    if [ ! -e "$serial_port" ]; then
        log_error "Serial port $serial_port not found"
        log_info "Available serial ports:"
        ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "No USB serial ports found"
        exit 1
    fi

    # Check permissions
    if [ ! -r "$serial_port" ] || [ ! -w "$serial_port" ]; then
        log_warn "No permission to access $serial_port"
        log_info "Add yourself to dialout group: sudo usermod -a -G dialout $USER"
        log_info "Or run with sudo"
    fi

    local terminal
    terminal=$(check_serial_tools)
    log_info "Using $terminal to connect to $serial_port at $baud_rate baud"
    log_info "Press Ctrl+A, X (minicom) or Ctrl+A, \\ (screen) to exit"

    case "$terminal" in
        minicom)
            exec minicom -D "$serial_port" -b "$baud_rate"
            ;;
        screen)
            exec screen "$serial_port" "$baud_rate"
            ;;
        picocom)
            exec picocom -b "$baud_rate" "$serial_port"
            ;;
    esac
}

connect_ssh() {
    local ip_address="$1"
    local username="$2"

    log_info "Connecting via SSH to $username@$ip_address..."

    if ! command -v ssh &> /dev/null; then
        log_error "SSH client not found"
        log_info "Install with: sudo apt install openssh-client"
        exit 1
    fi

    # Try to connect
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$username@$ip_address"
}

connect_raspberry() {
    log_info "Connecting to Raspberry Pi hardware..."
    echo "====================================="
    echo ""
    echo "Connection options for Raspberry Pi:"
    echo "1. SSH connection (if network is configured)"
    echo "2. Serial console via GPIO UART"
    echo "3. QEMU emulation (for testing)"
    echo ""
    read -p "Select connection method [1-3]: " choice

    case "$choice" in
        1)
            read -p "Enter Raspberry Pi IP address (default: 192.168.1.100): " pi_ip
            pi_ip="${pi_ip:-192.168.1.100}"
            log_info "Connecting via SSH to pi@$pi_ip..."
            connect_ssh "$pi_ip" "pi"
            ;;
        2)
            log_info "Connecting via serial console..."
            log_info "Required: USB-to-TTL serial adapter connected to GPIO pins"
            log_info "GPIO 14 (TXD) -> RX, GPIO 15 (RXD) -> TX, GND -> GND"
            read -p "Serial port (default: /dev/ttyUSB0): " pi_port
            pi_port="${pi_port:-/dev/ttyUSB0}"
            connect_hardware "$pi_port" "115200"
            ;;
        3)
            log_info "Starting Raspberry Pi QEMU emulation..."
            run_qemu "512M" false false false "raspberry"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

connect_beaglebone() {
    log_info "Connecting to BeagleBone hardware..."
    echo "===================================="
    echo ""
    echo "Connection options for BeagleBone:"
    echo "1. SSH connection (if network is configured)"
    echo "2. Serial console via USB (FTDI)"
    echo "3. Serial console via micro-USB"
    echo "4. QEMU emulation (for testing)"
    echo ""
    read -p "Select connection method [1-4]: " choice

    case "$choice" in
        1)
            read -p "Enter BeagleBone IP address (default: 192.168.7.2): " bb_ip
            bb_ip="${bb_ip:-192.168.7.2}"
            log_info "Connecting via SSH to root@$bb_ip..."
            connect_ssh "$bb_ip" "root"
            ;;
        2)
            log_info "Connecting via FTDI serial console..."
            log_info "Required: FTDI USB-to-serial adapter connected to J1 header"
            log_info "J1.1 (GND), J1.4 (RX), J1.5 (TX)"
            read -p "Serial port (default: /dev/ttyUSB0): " bb_port
            bb_port="${bb_port:-/dev/ttyUSB0}"
            connect_hardware "$bb_port" "115200"
            ;;
        3)
            log_info "Connecting via micro-USB serial console..."
            log_info "Required: micro-USB cable connected to BeagleBone"
            connect_hardware "/dev/ttyACM0" "115200"
            ;;
        4)
            log_info "Starting BeagleBone QEMU emulation..."
            run_qemu "512M" false false false "beaglebone"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

monitor_system() {
    log_info "System monitoring mode"
    echo "======================"

    echo "Available monitoring methods:"
    echo "1. SSH connection (if network is configured)"
    echo "2. Serial console connection"
    echo "3. QEMU console"
    echo ""

    read -p "Select method [1-3]: " choice

    case "$choice" in
        1)
            read -p "Enter robot IP address: " ip
            connect_ssh "${ip:-192.168.1.100}" "root"
            ;;
        2)
            connect_hardware "/dev/ttyUSB0" "115200"
            ;;
        3)
            log_info "Start QEMU in another terminal first"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

main() {
    local mode="qemu"
    local serial_port="/dev/ttyUSB0"
    local baud_rate="115200"
    local ip_address=""
    local username="root"
    local memory="512M"
    local enable_network=false
    local enable_graphics=false
    local debug=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--port)
                serial_port="$2"
                shift 2
                ;;
            -b|--baud)
                baud_rate="$2"
                shift 2
                ;;
            -i|--ip)
                ip_address="$2"
                shift 2
                ;;
            -u|--user)
                username="$2"
                shift 2
                ;;
            -m|--memory)
                memory="$2"
                shift 2
                ;;
            -n|--network)
                enable_network=true
                shift
                ;;
            -g|--graphics)
                enable_graphics=true
                shift
                ;;
            -d|--debug)
                debug=true
                shift
                ;;
            qemu|raspberry|beaglebone|hardware|ssh|monitor)
                mode="$1"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check if build directory exists
    if [ ! -d "$BUILD_DIR" ]; then
        log_error "Build directory not found: $BUILD_DIR"
        log_info "Run './scripts/build.sh' first to set up the Yocto environment"
        exit 1
    fi

    # Execute based on mode
    case "$mode" in
        qemu)
            run_qemu "$memory" "$enable_network" "$enable_graphics" "$debug" "qemu"
            ;;
        raspberry)
            connect_raspberry
            ;;
        beaglebone)
            connect_beaglebone
            ;;
        hardware)
            connect_hardware "$serial_port" "$baud_rate"
            ;;
        ssh)
            if [ -z "$ip_address" ]; then
                log_error "IP address required for SSH mode"
                log_info "Use: $0 ssh --ip <robot_ip>"
                exit 1
            fi
            connect_ssh "$ip_address" "$username"
            ;;
        monitor)
            monitor_system
            ;;
        *)
            log_error "Unknown mode: $mode"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
