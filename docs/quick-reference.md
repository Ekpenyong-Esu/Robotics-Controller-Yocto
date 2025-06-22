# Quick Start Guide: Building for Different Targets

This guide provides concise instructions for switching between target machine configurations and building the robotics controller image.

## Environment Setup

```bash
# Clone the repository (if not already done)
git clone <repository-url>
cd Robotics-Controller-Yocto

# Set up the environment (first time only)
source ./setup-yocto-env.sh
```

## Switch Target Machine Configuration

```bash
# Show available options
./scripts/change-machine.sh help

# BeagleBone Black
./scripts/change-machine.sh beaglebone

# Raspberry Pi 4
./scripts/change-machine.sh rpi4

# QEMU (virtual machine for testing)
./scripts/change-machine.sh qemu
```

## Build the Image

```bash
# Using the build script
./scripts/build.sh

# With clean build option
./scripts/build.sh --clean
```

## Flash the Image

```bash
# BeagleBone Black
./scripts/flash.sh --target bbb --device /dev/sdX

# Raspberry Pi 4
./scripts/flash.sh --target rpi4 --device /dev/sdX
```
Replace `/dev/sdX` with your actual SD card device path (use `lsblk` to identify it).

## Common Tasks

### Customize the Image

Edit the image recipe to add packages:
```bash
nano meta-robotics/recipes-core/images/robotics-image.bb
```

### Check Build Status

```bash
# View recent build logs
tail -f build/tmp/log/cooker/<machine>/console-latest.log

# List built images
ls -l build/tmp/deploy/images/<machine>/
```

### Clean Build Cache

```bash
# Clean all
./scripts/clean.sh

# Clean specific package
bitbake -c clean <package-name>
```

## Machine Configurations

- **beaglebone-robotics**: BeagleBone Black with real-time kernel for robotics
- **rpi4-robotics**: Raspberry Pi 4 with robotics-specific configurations
- **qemu-robotics**: QEMU virtual machine for testing

For detailed instructions, see [build-guide.md](./build-guide.md).
