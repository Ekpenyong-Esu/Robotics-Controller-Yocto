# Robotics Controller Scripts Guide

This directory contains the utility scripts for building, running, and maintaining the Embedded Robotics Controller project based on the Yocto Project build system.

## Command-Line Options Format

All scripts in this directory follow standard Unix/Linux command-line option conventions:

- Short options use a single dash and a single letter: `-h`, `-v`, `-c`
- Long options use double dashes and full words: `--help`, `--verbose`, `--clean`
- Most options have both short and long forms (shown as `-h, --help` in examples)
- Options may be combined for short form (e.g., `-xvf` for `-x -v -f`)
- All scripts support `-h` or `--help` to display usage information

## Overview of Scripts

| Script | Purpose |
|--------|---------|
| `build.sh` | Sets up the Yocto Project environment and manages the build process |
| `clean.sh` | Removes build artifacts and temporary files |
| `flash.sh` | Flashes the generated Yocto image to an SD card |
| `run.sh` | Runs the system in QEMU or connects to hardware |
| `save-config.sh` | Saves the current Yocto configuration |
| `manage-recipe.sh` | **NEW** - Manages meta-robotics layer recipes and source synchronization |
| `manage-layers.sh` | **NEW** - Comprehensive script for managing meta-layers in the Yocto build |

## Supported Target Machines

The project supports multiple hardware targets and virtual testing:

| Machine Name | Hardware | Description |
|--------------|----------|-------------|
| `beaglebone-robotics` | BeagleBone Black | Default target with real-time kernel and PRU support |
| `raspberrypi3` | Raspberry Pi 3 | ARM Cortex-A53 quad-core with GPIO support |
| `rpi4-robotics` | Raspberry Pi 4 | ARM Cortex-A72 quad-core with extended GPIO support |
| `qemu-robotics` | QEMU | Virtual machine for development and testing |

To select a specific machine target, use the `--machine` parameter with `build.sh`.

## Setup and Installation

### Prerequisites

Before using these scripts, ensure your host system meets the requirements:

- Ubuntu 20.04 LTS or newer
- At least 50GB free disk space
- Internet connection for package downloads
- Required packages installed (see below)

### Installing Dependencies

```bash
# Install required packages for Yocto development
sudo apt update
sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential \
  chrpath socat cpio python3 python3-pip python3-pexpect xz-utils \
  debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa \
  libsdl1.2-dev xterm python3-subunit mesa-common-dev zstd liblz4-tool
```

## Detailed Usage Instructions

### Building the System (`build.sh`)

This script sets up the Yocto build environment, downloads necessary repositories, and configures the build system.

#### Basic Usage

```bash
# Initialize with default settings (BeagleBone Black)
./scripts/build.sh

# Initialize for a specific target board
./scripts/build.sh -m, --machine rpi4-robotics

# Initialize for QEMU testing
./scripts/build.sh -q, --qemu

# Clean build (removes existing build directory first)
./scripts/build.sh -C, --clean

# Specify number of parallel jobs
./scripts/build.sh -j, --jobs 4

# Verbose output
./scripts/build.sh -v, --verbose

# Show help with all options
./scripts/build.sh -h, --help
```

#### Build Script Options

| Option | Short | Long | Description |
|--------|-------|------|-------------|
| Help | `-h` | `--help` | Display help message |
| Machine | `-m` | `--machine` | Specify machine target (e.g., `rpi4-robotics`, `beaglebone-robotics`) |
| QEMU | `-q` | `--qemu` | Configure for QEMU virtual machine target |
| Clean | `-C` | `--clean` | Clean build directory before setup |
| Jobs | `-j` | `--jobs` | Number of parallel jobs to use during build |
| Verbose | `-v` | `--verbose` | Enable verbose output during build process |

#### After Running `build.sh`

After running the build script, you need to:

1. Change to the build directory: `cd build`
2. Source the environment script: `source setup-environment`
3. Start the build: `bitbake robotics-controller-image`

### Cleaning Artifacts (`clean.sh`)

This script removes build artifacts and temporary files from the Yocto build process.

```bash
# Clean build outputs only (keeping downloads)
./scripts/clean.sh
# Alternative with explicit option
./scripts/clean.sh -b, --build-only

# Clean everything including downloads
./scripts/clean.sh -a, --all

# Clean just the shared state cache
./scripts/clean.sh -c, --cache

# Clean just the downloads
./scripts/clean.sh -d, --downloads

# Force clean without confirmation
./scripts/clean.sh -f, --force

# Show help with all options
./scripts/clean.sh -h, --help
```

#### Clean Script Options

| Option | Short | Long | Description |
|--------|-------|------|-------------|
| Help | `-h` | `--help` | Display help message |
| All | `-a` | `--all` | Clean everything including downloads |
| Build Only | `-b` | `--build-only` | Clean only build outputs |
| Cache | `-c` | `--cache` | Clean only shared state cache |
| Downloads | `-d` | `--downloads` | Clean only downloads directory |
| Force | `-f` | `--force` | Skip confirmation prompts |

### Flashing Images (`flash.sh`)

This script flashes the generated Yocto image to an SD card for use with physical hardware.

```bash
# Flash to an SD card
./scripts/flash.sh /dev/sdX  # Replace sdX with your SD card device

# Flash with verification (checksums the image after writing)
./scripts/flash.sh -v, --verify /dev/sdX

# Show available storage devices
./scripts/flash.sh -l, --list-devices

# Show available images
./scripts/flash.sh -s, --show-images

# Use specific image file
./scripts/flash.sh -i, --image path/to/image.wic.gz /dev/sdX

# Specify machine type
./scripts/flash.sh -m, --machine rpi4-robotics /dev/sdX

# Force flash without confirmation (be careful!)
./scripts/flash.sh -f, --force /dev/sdX

# Show help with all options
./scripts/flash.sh -h, --help
```

#### Flash Script Options

| Option | Short | Long | Description |
|--------|-------|------|-------------|
| Help | `-h` | `--help` | Display help message |
| Force | `-f` | `--force` | Skip safety confirmations |
| Verify | `-v` | `--verify` | Verify written data after flashing |
| Image | `-i` | `--image` | Use specific image file |
| List Devices | `-l` | `--list-devices` | List available storage devices |
| Show Images | `-s` | `--show-images` | Show available images |
| Machine | `-m` | `--machine` | Specify machine type for image selection |

⚠️ **IMPORTANT**: Always double-check the device name to avoid overwriting the wrong device!

### Running the System (`run.sh`)

This script runs the system in QEMU for virtual testing or connects to hardware via serial or SSH.

```bash
# Run in QEMU emulator (default)
./scripts/run.sh qemu

# Run QEMU with network support
./scripts/run.sh -n, --network

# Run QEMU with graphics
./scripts/run.sh -g, --graphics

# Run QEMU with more memory
./scripts/run.sh -m, --memory 1G

# Run with debugging enabled
./scripts/run.sh -d, --debug

# Connect to hardware via serial console
./scripts/run.sh hardware --port /dev/ttyUSB0

# Connect to hardware via SSH (requires IP address)
./scripts/run.sh ssh -i, --ip 192.168.1.100
```

#### Run Script Options

| Option | Short | Long | Description |
|--------|-------|------|-------------|
| Help | `-h` | `--help` | Display help message |
| Port | `-p` | `--port` | Serial port for hardware connection |
| Baud | `-b` | `--baud` | Baud rate for serial connection |
| IP | `-i` | `--ip` | IP address for SSH connection |
| User | `-u` | `--user` | Username for SSH connection |
| Memory | `-m` | `--memory` | Memory size for QEMU |
| Network | `-n` | `--network` | Enable network in QEMU |
| Graphics | `-g` | `--graphics` | Enable graphics in QEMU |
| Debug | `-d` | `--debug` | Enable debug output |

#### QEMU Controls

- `Ctrl+A, X` - Exit QEMU
- `Ctrl+A, C` - QEMU monitor console
- `Ctrl+A, H` - Help for more commands

### Saving Configuration (`save-config.sh`)

This script saves the current Yocto configuration for reuse, sharing, or comparison. It captures local.conf settings, layers, machine configurations, and other critical build parameters.

```bash
# Interactive mode (prompts for name)
./scripts/save-config.sh

# Save with specific name
./scripts/save-config.sh custom_config

# List existing configurations
./scripts/save-config.sh -l, --list

# Compare with existing configuration (generates diff)
./scripts/save-config.sh -d, --diff existing_config

# Force overwrite existing configuration
./scripts/save-config.sh -f, --force custom_config

# Show help with all options
./scripts/save-config.sh -h, --help
```

#### Save-Config Script Options

| Option | Short | Long | Description |
|--------|-------|------|-------------|
| Help | `-h` | `--help` | Display help message |
| Force | `-f` | `--force` | Overwrite existing configuration without confirmation |
| List | `-l` | `--list` | List existing configurations |
| Diff | `-d` | `--diff` | Show differences with existing configuration |

> **Note**: The current implementation does not support direct machine target selection via `--machine` or custom output file specification via `--output` options. The machine is determined from the current build configuration.

#### What Gets Saved

- Active layers and their revisions
- Machine configuration settings
- Local.conf customizations
- Distro features and package selections
- Kernel configuration options

### Meta-Robotics Recipe Management (`manage-recipe.sh`)

The `manage-recipe.sh` script provides comprehensive management of the meta-robotics layer recipes and source code synchronization.

**Key Features:**
- Synchronizes source code from `src/` to recipe files directory
- Validates meta-layer structure and dependencies
- Updates recipe checksums and version information
- Cleans recipe-specific build artifacts
- Tests recipe builds in isolation

**Common Usage:**
```bash
# Synchronize source code to recipe (run after source changes)
./scripts/manage-recipe.sh sync-src

# Validate meta-layer structure
./scripts/manage-recipe.sh validate

# Show recipe and source information
./scripts/manage-recipe.sh show-info

# Test recipe build
./scripts/manage-recipe.sh test-recipe

# Clean recipe-specific build files
./scripts/manage-recipe.sh clean-recipe
```

**Integration with Other Scripts:**
- `build.sh` automatically calls `sync-src` and `validate` before building
- `clean.sh` automatically calls `clean-recipe` when cleaning build artifacts
- `flash.sh` checks if source is newer than recipe and offers to sync

### Layer Management

### manage-layers.sh
**NEW** - Comprehensive script for managing meta-layers in the Yocto build.

**Usage**:
```bash
./scripts/manage-layers.sh [command] [options]
```

**Commands**:
- `list` - List all currently configured layers
- `available` - Show popular available meta-layers with URLs
- `add <name> <url> [branch]` - Add a new meta-layer
- `remove <name>` - Remove a meta-layer  
- `update <name>` - Update a meta-layer to latest commit
- `info <name>` - Show detailed information about a layer

**Examples**:
```bash
# List current layers
./scripts/manage-layers.sh list

# Show available layers
./scripts/manage-layers.sh available

# Add a new layer
./scripts/manage-layers.sh add meta-golang https://github.com/bmwcarit/meta-golang

# Add with specific branch
./scripts/manage-layers.sh add meta-ros https://github.com/ros/meta-ros scarthgap

# Remove a layer
./scripts/manage-layers.sh remove meta-golang

# Update a layer
./scripts/manage-layers.sh update meta-raspberrypi

# Get layer information
./scripts/manage-layers.sh info meta-security
```

### Popular Meta-Layers for Robotics

The following meta-layers are commonly useful for robotics projects:

#### Hardware BSP Layers
- **meta-ti** - Texas Instruments hardware (BeagleBone, etc.)
- **meta-raspberrypi** - Raspberry Pi support
- **meta-intel** - Intel hardware support
- **meta-xilinx** - Xilinx FPGA/SoC support

#### Real-time and Performance
- **meta-realtime** - Real-time kernel patches and tools
- **meta-latency-testing** - Tools for measuring system latency

#### Security
- **meta-security** - Security hardening features
- **meta-tpm** - Trusted Platform Module support
- **meta-selinux** - SELinux mandatory access control

#### Connectivity and IoT
- **meta-networking** - Additional networking packages
- **meta-bluetooth** - Bluetooth stack and utilities
- **meta-iot** - IoT frameworks and protocols

#### Development Languages
- **meta-nodejs** - Node.js runtime and packages
- **meta-python** - Extended Python packages
- **meta-rust** - Rust programming language
- **meta-golang** - Go programming language
- **meta-java** - Java support (OpenJDK)

#### Robotics and AI
- **meta-ros** - Robot Operating System (ROS)
- **meta-tensorflow-lite** - TensorFlow Lite for edge AI
- **meta-opencv** - OpenCV computer vision library

#### Multimedia and Graphics
- **meta-multimedia** - Audio and video packages
- **meta-qt5** - Qt5 GUI framework
- **meta-gnome** - GNOME desktop environment

#### Virtualization
- **meta-virtualization** - Docker, LXC, and other containers
- **meta-cloud-services** - Cloud service integration

## Common Workflows

### First-time Setup and Build

```bash
# 1. Initialize the build environment for BeagleBone Black
./scripts/build.sh

# 2. Enter the build environment
cd build
source setup-environment

# 3. Build the image
bitbake robotics-controller-image
```

### Developing with QEMU

```bash
# 1. Initialize for QEMU testing
./scripts/build.sh --qemu

# 2. Enter the build environment and build
cd build
source setup-environment
bitbake robotics-controller-image

# 3. Run in QEMU with networking
./scripts/run.sh --network

# 4. Make changes to your source code in src/robotics-controller/

# 5. Rebuild only the robotics controller package
cd build
source setup-environment
bitbake robotics-controller -c cleansstate
bitbake robotics-controller

# 6. Run again with QEMU to test changes
./scripts/run.sh --graphics
```

#### QEMU Benefits for Development

- Fast testing cycle without flashing physical hardware
- Network connectivity to test web interface
- Graphical capability to test vision processing
- Debugging support with GDB integration
- Ability to test most software features before deploying to hardware

### Deploying to Hardware

```bash
# 1. List available images
./scripts/flash.sh --show-images

# 2. List available devices
./scripts/flash.sh --list-devices

# 3. Flash to SD card with verification
./scripts/flash.sh --verify /dev/sdX

# 4. Connect to hardware via serial console
./scripts/run.sh hardware
```

### Cleaning and Rebuilding

```bash
# 1. Clean build artifacts
./scripts/clean.sh --build-only

# 2. Rebuild
cd build
source setup-environment
bitbake robotics-controller-image -c cleansstate
bitbake robotics-controller-image
```

## Troubleshooting

### Build Failures

If a build fails:

1. Check the error logs in `build/tmp/log/`
2. Clean the specific package: `bitbake <package-name> -c cleansstate`
3. Try building again

### QEMU Environment Setup

- Ensure QEMU packages are installed: `sudo apt install qemu-system-arm`
- Check if virtualization is enabled in BIOS (for better performance)

### Flashing Problems

- Make sure SD card is not mounted: `umount /dev/sdX*`
- Try a different card reader or SD card
- Run `dmesg` after inserting the SD card to identify the correct device

### Access Issues

- Permission denied: Run scripts with `sudo` or add your user to appropriate groups:

```bash
sudo usermod -a -G dialout $USER  # For serial access
```

## Troubleshooting Common Issues

### Build Problems

#### Failed Fetching Sources

```bash
# Check your internet connection and try again
# Sometimes source mirrors might be temporarily unavailable

# You can also try cleaning the download cache
./scripts/clean.sh --downloads

# Then restart the build
./scripts/build.sh
```

#### Out of Disk Space

```bash
# Check available space
df -h

# Clean temporary files
./scripts/clean.sh --tmp

# Consider mounting a larger filesystem to the build directory
```

#### Insufficient Memory

```bash
# Reduce parallel jobs
./scripts/build.sh --jobs 2

# Add swap space if needed
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### QEMU Troubleshooting

#### KVM Acceleration Problems

```bash
# Check if KVM is available
ls -l /dev/kvm

# If missing, check if virtualization is enabled in BIOS
# Also ensure you're running as a user with kvm group membership
sudo usermod -a -G kvm $USER
```

#### Network Connection in QEMU

```bash
# If you cannot connect to the network in QEMU, try specifying
# the network interface type
./scripts/run.sh --network-device virtio-net-pci

# Check host firewall settings
sudo ufw status
```

#### Graphics Not Working

```bash
# Make sure you have required libraries
sudo apt install libsdl2-2.0-0

# Try with software rendering
./scripts/run.sh --graphics --disable-gl
```

### Hardware Interface Issues

#### SD Card Not Recognized

```bash
# List block devices
lsblk

# Check dmesg for errors
dmesg | tail

# Try a different SD card reader
```

#### Serial Connection Problems

```bash
# List available serial ports
ls -l /dev/ttyUSB*
ls -l /dev/ttyACM*

# Add user to dialout group for serial access
sudo usermod -a -G dialout $USER
```

For more detailed troubleshooting, refer to the `docs/troubleshooting.md` file in the project root.

## Further Resources

- Yocto Project Documentation: [https://docs.yoctoproject.org/](https://docs.yoctoproject.org/)
- BeagleBone Black Documentation: [https://beagleboard.org/black](https://beagleboard.org/black)
- Project Wiki: See the `/docs` directory for detailed documentation

## Yocto Layer Structure and Organization

Our custom Yocto Project layer, `meta-robotics`, is structured as follows:

### Layer Overview

```text
meta-robotics/
├── conf/                      # Layer configuration
│   ├── layer.conf              # Layer definition
│   ├── templates/              # Template configurations
│   │   ├── bblayers.conf         # Layer template
│   │   └── local.conf           # Build config template
│   └── machine/                # Machine configurations
│       ├── beaglebone-robotics.conf
│       ├── rpi4-robotics.conf
│       └── qemu-robotics.conf
├── recipes-core/              # Core system recipes
│   └── images/
│       └── robotics-controller-image.bb  # Main image definition
├── recipes-robotics/          # Custom robotics application
│   └── robotics-controller/    # Main application recipe
│       ├── files/              # Application source files
│       │   └── src/            # Source code
│       └── robotics-controller_1.0.bb    # Recipe file
└── recipes-kernel/            # Kernel customizations
    └── linux/                  # Linux kernel configuration
        ├── linux-yocto-rt_%.bbappend     # BeagleBone kernel
        ├── linux-raspberrypi-rt_%.bbappend  # RPi4 kernel
        └── linux-yocto-rt/     # Kernel configurations
            ├── rt-preemption.cfg   # Real-time features
            ├── i2c.cfg             # I2C support
            ├── spi.cfg             # SPI support
            ├── gpio.cfg            # GPIO support
            ├── pwm.cfg             # PWM support
            ├── v4l2.cfg            # Video4Linux support
            ├── robotics-platform.cfg   # Common platform config
            └── robotics-platform-rpi.cfg  # Raspberry Pi specific
```

### Key Recipes

1. **robotics-controller-image.bb**:  
   - Defines the complete system image with all required packages
   - Includes essential tools, libraries, and the robotics application

2. **robotics-controller_1.0.bb**:
   - Builds the main robotics application from C++ source
   - Sets up service files for automatic startup
   - Installs configuration files

3. **linux-yocto-rt_%.bbappend**:
   - Extends the real-time Linux kernel for robotics-specific features
   - Applies custom patches and configuration fragments
   - Enables required drivers for hardware interfaces

## Developing with the Yocto SDK

The Yocto Project can generate an SDK (Software Development Kit) that provides a cross-compilation environment for developing applications outside the Yocto build system.

### Building the SDK

```bash
# First build the image
./scripts/build.sh

# Enter the build environment
cd build
source setup-environment

# Build the SDK
bitbake robotics-controller-image -c populate_sdk
```

The SDK will be created in `build/tmp/deploy/sdk/` as a self-extracting installer.

### Installing the SDK

```bash
# Make installer executable
chmod +x tmp/deploy/sdk/poky-glibc-x86_64-robotics-controller-image-armv7at2hf-neon-beaglebone-robotics-toolchain-*.sh

# Run installer (default install location is /opt/poky)
./tmp/deploy/sdk/poky-glibc-x86_64-robotics-controller-image-armv7at2hf-neon-beaglebone-robotics-toolchain-*.sh
```

### Using the SDK

```bash
# Source environment setup script
source /opt/poky/*/environment-setup-armv7at2hf-neon-poky-linux-gnueabi

# Now cross-compiling tools are in your PATH
echo $CC  # Should show the cross compiler

# Example compiling a C++ application
$CXX main.cpp -o my_application
```

### Benefits of Using the SDK

1. **Rapid Development**: Develop and test applications outside the full Yocto build
2. **IDE Integration**: Works with Visual Studio Code and other IDEs
3. **Consistent Environment**: Ensures compatibility with target system
4. **Includes Dependencies**: All libraries and headers from the image are available

### Example: Visual Studio Code Integration

1. Install the C/C++ extension in VS Code
2. Source the SDK environment before launching VS Code:

   ```bash
   source /opt/poky/*/environment-setup-*
   code .
   ```

3. Configure `c_cpp_properties.json` to use the cross compiler from the SDK

## Conclusion and Next Steps

This scripts directory provides a comprehensive set of tools for building, testing, and deploying the Embedded Robotics Controller. These scripts simplify the complex process of working with Yocto Project and enable both hardware and virtual development.

### Script Standards Compliance

All scripts in this project follow these standards:

- **POSIX Compliance**: Scripts use POSIX-compatible shell features for maximum portability
- **Exit Codes**: Scripts return appropriate exit codes (0 for success, non-zero for failure)
- **Error Handling**: Scripts use error handling to detect and report issues (set -e)
- **Command Line Parsing**: Standard GNU-style short/long options with getopt compatibility
- **Color Output**: Uses ANSI color codes for readability with fallback for non-color terminals
- **Help Documentation**: Each script includes comprehensive usage documentation

### Version Information

- **Last Updated**: June 13, 2025
- **Compatibility**: Yocto Project "Scarthgap" release
- **Tested Environments**: Ubuntu 22.04, Ubuntu 24.04, Debian 12

### Next Steps

After getting familiar with these scripts and the basic build process, consider:

1. **Customizing the Image**: Edit `meta-robotics/recipes-core/images/robotics-controller-image.bb` to add or remove packages
2. **Modifying the Kernel**: Add kernel features through configuration fragments in the `meta-robotics/recipes-kernel/linux/linux-yocto-rt/` directory
3. **Adding New Features**: Develop additional robotics controller features in the `src/robotics-controller/` directory
4. **Testing with Sensors**: Connect actual sensors and test with the hardware interfaces

### Additional Resources

- [Yocto Project Documentation](https://docs.yoctoproject.org/)
- [BeagleBone Black Documentation](https://beagleboard.org/black)
- [Raspberry Pi 4 Documentation](https://www.raspberrypi.org/documentation/)
- [QEMU Documentation](https://www.qemu.org/docs/master/)
- [OpenEmbedded Layer Index](https://layers.openembedded.org/)

### Getting Help

For questions and support:

- Check the project documentation in the `docs/` directory
- Create an issue in the project repository
- Refer to the Yocto Project community resources

Happy robot building!
