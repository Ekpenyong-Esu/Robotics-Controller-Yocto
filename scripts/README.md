# Simplified Scripts for Robotics Controller

This directory contains simplified scripts for building, running, and managing the robotics controller with Yocto.

## Available Scripts

### Core Scripts

-   **`build.sh`** - Simplified build script with machine selection
-   **`clean.sh`** - Clean build artifacts and directories
-   **`run.sh`** - Run QEMU images for testing
-   **`flash.sh`** - Flash images to SD cards
-   **`test-qemu-login.sh`** - Test QEMU image login

### Advanced Scripts

-   **`dual-env.sh`** - Manage multiple build environments
-   **`save-config.sh`** - Save and manage build configurations
-   **`sync-meta-layer.sh`** - Sync meta-robotics layer
-   **`verify-implementation.sh`** - Verify project structure
-   **`manage-layers.sh`** - Manage Yocto meta-layers
-   **`manage-recipe.sh`** - Manage recipe development

### Build Script Usage

```bash
# Build with defaults (qemu-robotics, robotics-qemu-image)
./scripts/build.sh

# Build for specific machine
./scripts/build.sh rpi3-robotics

# Build for Raspberry Pi 4
./scripts/build.sh rpi4-robotics

# Build specific machine and image
./scripts/build.sh qemu-robotics robotics-controller-image
```

**Supported Machines:**

-   `qemu-robotics` - QEMU Robotics Testing (default)
-   `beaglebone-robotics` - BeagleBone Black Robotics Platform
-   `rpi3-robotics` - Raspberry Pi 3 Robotics Platform
-   `rpi4-robotics` - Raspberry Pi 4 Robotics Platform

**Available Images:**

-   `robotics-qemu-image` - QEMU testing image (default)
-   `robotics-controller-image` - Production robotics image
-   `robotics-controller-dev` - Development image with tools
-   `robotics-image` - Basic robotics image

### Clean Script Usage

```bash
# Clean build directory only (default)
./scripts/clean.sh

# Clean everything
./scripts/clean.sh --all

# Clean only downloads cache
./scripts/clean.sh --downloads

# Clean only output directory
./scripts/clean.sh --output
```

### Run Script Usage

```bash
# Run default QEMU (qemu-robotics, robotics-qemu-image)
./scripts/run.sh

# Run specific machine
./scripts/run.sh qemu-robotics

# Run specific machine and image
./scripts/run.sh qemu-robotics robotics-qemu-image
```

**Note:** Only QEMU machines are supported in simplified mode.

### Flash Script Usage

```bash
# Flash default image to SD card
./scripts/flash.sh /dev/sdb

# Flash specific image file
./scripts/flash.sh /dev/mmcblk0 custom.ext4
```

**⚠️ Warning:** This will completely erase the target device!

### Test Script Usage

```bash
# Test QEMU login functionality
./scripts/test-qemu-login.sh
```

## Quick Start

1. **Build a QEMU image:**

    ```bash
    ./scripts/build.sh qemu-robotics robotics-qemu-image
    ```

2. **Test the image:**

    ```bash
    ./scripts/test-qemu-login.sh
    ```

3. **Build for hardware:**

    ```bash
    ./scripts/build.sh rpi4-robotics robotics-controller-image
    ```

4. **Flash to SD card:**

    ```bash
    ./scripts/flash.sh /dev/sdb
    ```

## Login Credentials

**QEMU Images:**

-   Username: `root`
-   Password: `robotics2025` (or try empty password)

## Getting Help

Run any script with `-h` or `--help` for detailed usage information:

```bash
./scripts/build.sh --help
./scripts/clean.sh --help
./scripts/run.sh --help
./scripts/flash.sh --help
```

## Original Complex Scripts

The original complex scripts with advanced features have been simplified. If you need the advanced functionality (dependency checking, complex layer management, hardware connections, etc.), you can restore them from git history or use the backup versions if available.

### Layer Management Script Usage

```bash
# List currently configured layers
./scripts/manage-layers.sh list

# Add a new meta-layer
./scripts/manage-layers.sh add meta-ros https://github.com/ros/meta-ros

# Remove a meta-layer
./scripts/manage-layers.sh remove meta-ros
```

### Recipe Management Script Usage

```bash
# Sync source code to meta-robotics recipe
./scripts/manage-recipe.sh sync

# Validate recipe structure
./scripts/manage-recipe.sh validate

# Clean recipe build artifacts
./scripts/manage-recipe.sh clean
```

### Dual Environment Script Usage

```bash
# Setup environment for different machines
./scripts/dual-env.sh setup qemu
./scripts/dual-env.sh setup beaglebone
./scripts/dual-env.sh setup rpi3
./scripts/dual-env.sh setup rpi4

# Build in specific environment
./scripts/dual-env.sh build qemu

# Check environment status
./scripts/dual-env.sh status
```

### Other Advanced Scripts

```bash
# Save current build configuration
./scripts/save-config.sh my-config

# Sync meta-robotics layer
./scripts/sync-meta-layer.sh sync

# Verify project implementation
./scripts/verify-implementation.sh
```

**Configuration Templates:**

The build script automatically applies machine-specific configuration templates:

-   Each machine has optimized `local.conf` and `bblayers.conf` files
-   Templates are located in `meta-robotics/conf/templates/<machine>-config/`
-   Original configurations are automatically backed up with timestamps
-   No manual configuration copying required
