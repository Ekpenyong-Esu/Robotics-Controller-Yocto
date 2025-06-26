# Meta-Robotics Configuration Directory

This directory contains all configuration files and templates for the meta-robotics Yocto layer. These files define machine configurations, layer dependencies, and build templates for different robotics platforms.

## 📁 Directory Structure

```
conf/
├── layer.conf                 # Layer configuration and metadata
├── machine/                   # Machine-specific configurations
│   ├── beaglebone-robotics.conf    # BeagleBone Black robotics machine
│   ├── rpi4-robotics.conf          # Raspberry Pi 4 robotics machine
│   └── qemu-robotics.conf          # QEMU emulation machine
└── templates/                 # Build configuration templates
    ├── bblayers.conf              # General layer configuration
    ├── local.conf                 # General build configuration
    ├── beaglebone-config/          # BeagleBone-specific templates
    │   ├── bblayers.conf
    │   └── local.conf
    └── qemu-config/               # QEMU-specific templates
        ├── bblayers.conf
        └── local.conf
```

## 🔧 Configuration Files Overview

### Layer Configuration

#### `layer.conf`
**Purpose**: Defines the meta-robotics layer metadata and tells Yocto about our layer.

**Key Functions**:
- Registers the layer with BitBake
- Defines recipe search paths
- Sets layer priority and dependencies  
- Specifies Yocto version compatibility

**Configuration Details**:
```bitbake
# Layer identification
BBFILE_COLLECTIONS += "meta-robotics"
BBFILE_PRIORITY_meta-robotics = "10"

# Recipe locations
BBFILES += "${LAYERDIR}/recipes-*/*/*.bb ${LAYERDIR}/recipes-*/*/*.bbappend"

# Dependencies and compatibility
LAYERDEPENDS_meta-robotics = "core"
LAYERSERIES_COMPAT_meta-robotics = "langdale mickledore nanbield scarthgap"
```

### Machine Configurations

Machine configurations define hardware-specific settings, kernel choices, and feature sets for different robotics platforms.

#### `machine/beaglebone-robotics.conf`
**Purpose**: BeagleBone Black configuration optimized for robotics applications.

**Hardware Features**:
- TI AM335x ARM Cortex-A8 1GHz processor
- 512MB DDR3 RAM, 4GB eMMC storage
- 92 expansion pins (GPIO, I2C, SPI, UART, PWM, ADC)
- Real-time PRU (Programmable Real-time Unit) subsystem

**Robotics Features Enabled**:
- Real-time kernel (`linux-yocto-rt`) with PREEMPT_RT
- Hardware interfaces: GPIO, I2C, SPI, UART, PWM, ADC
- Custom device tree (`am335x-boneblack-robotics.dtb`)
- PRU support for ultra-low latency operations

**Key Configuration**:
```bitbake
MACHINE_FEATURES += "robotics gpio i2c spi uart"
PREFERRED_PROVIDER_virtual/kernel = "linux-yocto-rt"
KERNEL_DEVICETREE = "am335x-boneblack-robotics.dtb"
MACHINE_ESSENTIAL_EXTRA_RDEPENDS += "robotics-controller"
```

#### `machine/rpi4-robotics.conf`
**Purpose**: Raspberry Pi 4 configuration optimized for computer vision robotics.

**Hardware Features**:
- Broadcom BCM2711 ARM Cortex-A72 quad-core 1.5GHz
- 1GB-8GB LPDDR4 RAM (model dependent)
- VideoCore VI GPU with hardware acceleration
- 40-pin GPIO header, Wi-Fi 802.11ac, Bluetooth 5.0

**Robotics Features Enabled**:
- Hardware-accelerated computer vision (VideoCore GPU)
- Wireless communication (Wi-Fi, Bluetooth)
- Camera interface (CSI) for vision applications
- GPIO, I2C, SPI, UART interfaces

**Key Configuration**:
```bitbake
MACHINE_FEATURES += "robotics gpio i2c spi uart bluetooth wifi"
GPU_MEM = "64"  # Allocate memory for video acceleration
ENABLE_UART = "1"  # Enable serial communication
```

#### `machine/qemu-robotics.conf`
**Purpose**: QEMU ARM64 emulation for development and testing without physical hardware.

**Emulation Features**:
- ARM64 (AArch64) processor emulation
- 512MB virtual RAM
- Network connectivity for development
- Software-only testing environment

**Use Cases**:
- Algorithm development without hardware
- CI/CD pipeline testing
- Multi-platform compatibility verification
- Training and educational purposes

**Key Configuration**:
```bitbake
require conf/machine/qemuarm64.conf
MACHINE_FEATURES += "robotics"
QB_MEM = "512M"
```

### Build Templates

Build templates provide ready-to-use configurations for different development scenarios.

#### `templates/bblayers.conf`
**Purpose**: General layer configuration template for all platforms.

**Included Layers**:
- **Core Yocto**: `meta`, `meta-poky`, `meta-yocto-bsp`
- **OpenEmbedded**: `meta-oe`, `meta-python`, `meta-networking`, `meta-multimedia`
- **Hardware**: `meta-raspberrypi` (when needed)
- **Application**: `meta-robotics`

**Usage**:
```bash
cp meta-robotics/conf/templates/bblayers.conf build/conf/bblayers.conf
```

#### `templates/local.conf`
**Purpose**: General build configuration with robotics optimizations.

**Key Features**:
- Machine selection (configurable)
- Development tools and SSH access
- OpenCV with Python3 support
- Real-time kernel preference
- Debug features for development

**Security Note**: Contains development conveniences that should be removed for production.

#### Platform-Specific Templates

##### `templates/beaglebone-config/`
BeagleBone Black optimized configurations:
- **Hardware focus**: Real-time performance, PRU support, hardware interfaces
- **Kernel**: PREEMPT_RT for deterministic timing
- **Features**: GPIO, I2C, SPI, PWM, ADC support
- **Optimization**: Build performance and eMMC deployment

##### `templates/qemu-config/`
QEMU emulation optimized configurations:
- **Development focus**: Testing, debugging, algorithm development
- **Tools**: Comprehensive development toolset
- **Features**: Software testing without hardware dependencies
- **Optimization**: Fast emulation and debugging capabilities

## 🚀 How to Use These Configurations

### 1. Setting Up a New Build Environment

Choose the appropriate template based on your target platform:

#### For BeagleBone Black Development:
```bash
# Initialize build environment
source poky/oe-init-build-env build-beaglebone

# Copy BeagleBone-specific templates
cp ../meta-robotics/conf/templates/beaglebone-config/local.conf conf/local.conf
cp ../meta-robotics/conf/templates/beaglebone-config/bblayers.conf conf/bblayers.conf

# Build robotics image
bitbake robotics-image
```

#### For Raspberry Pi 4 Development:
```bash
# Initialize build environment  
source poky/oe-init-build-env build-rpi4

# Copy general templates and modify for RPi4
cp ../meta-robotics/conf/templates/local.conf conf/local.conf
cp ../meta-robotics/conf/templates/bblayers.conf conf/bblayers.conf

# Edit local.conf to set machine
sed -i 's/MACHINE ?= "beaglebone-robotics"/MACHINE ?= "rpi4-robotics"/' conf/local.conf

# Build robotics image
bitbake robotics-image
```

#### For QEMU Emulation:
```bash
# Initialize build environment
source poky/oe-init-build-env build-qemu

# Copy QEMU-specific templates
cp ../meta-robotics/conf/templates/qemu-config/local.conf conf/local.conf
cp ../meta-robotics/conf/templates/qemu-config/bblayers.conf conf/bblayers.conf

# Build and run emulation
bitbake robotics-image
runqemu qemu-robotics robotics-image
```

### 2. Customizing Configurations

#### Machine Selection
Change the target platform by modifying `MACHINE` in `local.conf`:
```bitbake
MACHINE ?= "beaglebone-robotics"  # BeagleBone Black
MACHINE ?= "rpi4-robotics"        # Raspberry Pi 4  
MACHINE ?= "qemu-robotics"        # QEMU emulation
```

#### Adding Development Features
For development builds, ensure these features are enabled:
```bitbake
IMAGE_FEATURES:append = " debug-tweaks ssh-server-openssh tools-debug"
EXTRA_USERS_PARAMS = "usermod -P robotics root;"
```

#### Production Hardening
For production builds, remove development features:
```bitbake
# Remove debug features
EXTRA_IMAGE_FEATURES:remove = "debug-tweaks"
IMAGE_FEATURES:remove = "tools-debug"

# Remove default password
# EXTRA_USERS_PARAMS = "usermod -P robotics root;"  # Comment out

# Enable security features
DISTRO_FEATURES:append = " pam systemd"
EXTRA_IMAGE_FEATURES:append = " read-only-rootfs"
```

## 🔍 Configuration Details by Platform

### BeagleBone Black Robotics Platform

**Optimal for**: Real-time robotics applications, motor control, sensor integration

**Hardware Capabilities**:
- **Real-time Performance**: PREEMPT_RT kernel with deterministic timing
- **Hardware Interfaces**: 92 pins with GPIO, I2C, SPI, UART, PWM, ADC
- **PRU Subsystem**: 200MHz real-time processors for ultra-low latency
- **Industrial I/O**: 8-channel 12-bit ADC for analog sensors
- **Storage**: 4GB eMMC for reliable embedded deployment

**Software Stack**:
- **Kernel**: `linux-yocto-rt` with real-time patches
- **Device Tree**: Custom robotics hardware configuration
- **Drivers**: TI AM335x optimized drivers for all interfaces
- **Applications**: Full robotics controller software suite

### Raspberry Pi 4 Robotics Platform

**Optimal for**: Computer vision robotics, wireless operation, prototyping

**Hardware Capabilities**:
- **Processing Power**: Quad-core 1.5GHz with up to 8GB RAM
- **GPU Acceleration**: VideoCore VI for computer vision processing
- **Connectivity**: Wi-Fi 802.11ac, Bluetooth 5.0, Gigabit Ethernet
- **Interfaces**: 40-pin GPIO with I2C, SPI, UART support
- **Camera**: CSI interface for high-resolution camera modules

**Software Stack**:
- **Graphics**: Hardware-accelerated OpenGL ES and video processing
- **Wireless**: Full Wi-Fi and Bluetooth stack
- **Computer Vision**: GPU-accelerated OpenCV and ML frameworks
- **Development**: Rich ecosystem of Python libraries and tools

### QEMU Robotics Emulation

**Optimal for**: Algorithm development, testing, CI/CD, training

**Emulation Capabilities**:
- **Processor**: ARM64 emulation with configurable resources
- **Memory**: 512MB default (configurable up to host limits)
- **Networking**: NAT and bridge networking for connectivity
- **Development**: Full debugging and profiling tool suite

**Software Environment**:
- **Testing**: Comprehensive unit testing and validation frameworks
- **Debugging**: GDB, strace, performance monitoring tools
- **Networking**: Complete network testing and protocol validation
- **Portability**: Same software stack as physical hardware

## 🛠️ Troubleshooting Configuration Issues

### Common Issues and Solutions

#### Layer Path Errors
**Problem**: BitBake cannot find meta-robotics layer
```bash
ERROR: Unable to find matching sigdata for meta-robotics
```
**Solution**: Check layer paths in `bblayers.conf` match your directory structure:
```bash
# Verify layer exists
ls -la meta-robotics/conf/layer.conf

# Check path in bblayers.conf matches actual location
grep meta-robotics build/conf/bblayers.conf
```

#### Machine Configuration Not Found
**Problem**: Unknown machine configuration
```bash
ERROR: Invalid MACHINE beaglebone-robotics
```
**Solution**: Verify machine configuration file exists:
```bash
# Check machine file exists
ls -la meta-robotics/conf/machine/beaglebone-robotics.conf

# Verify MACHINE setting in local.conf
grep MACHINE build/conf/local.conf
```

#### Missing Dependencies
**Problem**: Layer dependency errors
```bash
ERROR: Layer meta-robotics depends on layer core
```
**Solution**: Ensure all required layers are included in `bblayers.conf`:
```bash
# Check layer dependencies
grep LAYERDEPENDS meta-robotics/conf/layer.conf

# Verify all dependencies are in bblayers.conf
grep -E "(meta|poky)" build/conf/bblayers.conf
```

#### Build Performance Issues
**Problem**: Slow build times
**Solution**: Optimize build settings in `local.conf`:
```bitbake
# Use all CPU cores
BB_NUMBER_THREADS ?= "${@oe.utils.cpu_count()}"
PARALLEL_MAKE ?= "-j ${@oe.utils.cpu_count()}"

# Use shared state cache
SSTATE_DIR ?= "/opt/yocto/sstate-cache"

# Use persistent download directory
DL_DIR ?= "/opt/yocto/downloads"
```

### Configuration Validation

#### Check Layer Configuration
```bash
# Validate layer.conf syntax
bitbake-layers show-layers

# Check layer dependencies
bitbake-layers show-cross-depends

# Verify machine configurations
bitbake -e | grep "^MACHINE="
```

#### Validate Build Configuration
```bash
# Check local.conf syntax
bitbake -e | grep -E "(MACHINE|DISTRO)="

# Verify feature configuration
bitbake -e | grep "MACHINE_FEATURES="

# Check image features
bitbake -e | grep "IMAGE_FEATURES="
```

## 📋 Configuration Summary

| Platform | Machine Config | Kernel | Key Features | Use Case |
|----------|----------------|--------|--------------|----------|
| BeagleBone Black | `beaglebone-robotics.conf` | `linux-yocto-rt` | Real-time, PRU, Hardware I/O | Motor control, real-time robotics |
| Raspberry Pi 4 | `rpi4-robotics.conf` | `linux-yocto-rt` | GPU acceleration, Wireless | Computer vision, prototyping |
| QEMU ARM64 | `qemu-robotics.conf` | `linux-yocto` | Emulation, Development tools | Testing, algorithm development |

This configuration framework provides a complete foundation for robotics development across multiple platforms with proper hardware abstraction and optimization for each target environment.
