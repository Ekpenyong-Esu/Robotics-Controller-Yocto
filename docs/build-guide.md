# Robotics Controller Build Guide

This guide explains how to set up the environment, switch between different target machine configurations, and build the Robotics Controller image from start to finish.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Environment Configuration](#environment-configuration)
3. [Switching Machine Configurations](#switching-machine-configurations)
4. [Building the Image](#building-the-image)
5. [Flashing the Image](#flashing-the-image)
6. [Troubleshooting](#troubleshooting)

## Initial Setup

Before you begin, make sure you have the necessary host dependencies installed:

```bash
# Install required packages for Yocto builds
sudo apt update
sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential \
     chrpath socat cpio python3 python3-pip python3-pexpect xz-utils \
     debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa \
     libsdl1.2-dev xterm python3-subunit mesa-common-dev zstd liblz4-tool
```

## Environment Configuration

First, set up the build environment. This process clones the necessary repositories and prepares the build configuration.

```bash
# Navigate to the project directory
cd /path/to/Robotics-Controller-Yocto

# Source the setup script
source ./setup-yocto-env.sh
```

During this process:

1. If Poky (Yocto Project reference distribution) is not cloned, you'll be prompted to clone it.
2. If meta-openembedded is not cloned, you'll be prompted to clone it.
3. If meta-raspberrypi is not cloned, you'll be prompted to clone it (needed only for Raspberry Pi builds).

The script will:
- Initialize the Yocto build environment
- Add the meta-robotics layer to the build configuration
- Set up basic machine configurations

## Switching Machine Configurations

You can easily switch between different target machine configurations using the provided script:

```bash
# View available options
./scripts/change-machine.sh help

# Switch to BeagleBone Black configuration
./scripts/change-machine.sh beaglebone

# Switch to Raspberry Pi 4 configuration
./scripts/change-machine.sh rpi4

# Switch to QEMU for virtual testing
./scripts/change-machine.sh qemu
```

### Available Machine Configurations

1. **beaglebone-robotics** - BeagleBone Black with robotics-specific configurations
   - Real-time kernel optimized for robotics control
   - Custom device tree with pin configurations for sensors and actuators
   - PRU support for real-time tasks

2. **rpi4-robotics** - Raspberry Pi 4 with robotics-specific configurations
   - Optimized settings for GPIO, I2C, SPI interfaces
   - Camera and multimedia support
   - Real-time Linux patches

3. **qemu-robotics** - QEMU virtual machine for testing
   - Allows testing without physical hardware
   - Useful for software development and CI/CD pipelines

## Building the Image

Once you've selected the appropriate machine configuration, build the image:

```bash
# Navigate to the project directory
cd /path/to/Robotics-Controller-Yocto

# Use the build script (recommended)
./scripts/build.sh

# Alternatively, use BitBake directly
source ./setup-yocto-env.sh  # If not already sourced
bitbake robotics-image
```

### Build Options

The `build.sh` script provides several options:

```bash
# Clean build (removes existing build directory)
./scripts/build.sh --clean

# Verbose output
./scripts/build.sh --verbose

# Specify number of parallel jobs
./scripts/build.sh --jobs 8
```

### Build Process

The build process involves several stages:

1. **Fetching sources** - Downloads all required source code
2. **Extracting and patching** - Prepares source code for building
3. **Configuration** - Sets up build system
4. **Compilation** - Builds all components
5. **Package creation** - Creates installable packages
6. **Image generation** - Builds the final system image

The complete build may take 1-3 hours depending on your system's capabilities and internet connection speed.

## Flashing the Image

Once the build completes successfully, you can flash the image to your target board:

```bash
# For BeagleBone Black
./scripts/flash.sh --target bbb --device /dev/sdX

# For Raspberry Pi 4
./scripts/flash.sh --target rpi4 --device /dev/sdX
```

Replace `/dev/sdX` with the actual device path of your SD card (e.g., `/dev/sdc`). **Be extremely careful** to specify the correct device to avoid overwriting your system drives!

## Troubleshooting

If you encounter issues during the build process:

1. **Build failures**: Check the log file at `build/tmp/log/cooker/<machine>/console-latest.log`
2. **Missing dependencies**: Ensure all required host packages are installed
3. **Disk space issues**: Yocto builds require at least 50GB of free space
4. **Network problems**: Ensure you have a stable internet connection for downloading sources

For additional troubleshooting help, refer to the [troubleshooting.md](./troubleshooting.md) document.

## Advanced Configuration

### Custom Package Inclusion

To add additional packages to your image, edit the `meta-robotics/recipes-core/images/robotics-image.bb` file:

```bitbake
IMAGE_INSTALL:append = " \
    package-name \
    another-package \
"
```

### Hardware Customization

For hardware-specific configurations, check the machine configuration files in `meta-robotics/conf/machine/`.

### Kernel Customization

To modify kernel configurations:
1. Create or modify `.cfg` files in `meta-robotics/recipes-kernel/linux/linux-yocto-rt/`
2. Reference these in the appropriate kernel recipe append file
