# Robotics Controller - Core Recipes

This directory contains the core image recipes for the robotics controller Yocto layer. These recipes define different system images optimized for various use cases, from production deployment to development and testing.

## 📁 Directory Structure

```text
recipes-core/
├── README.md                          # This file
└── images/
    ├── robotics-controller-image.bb   # Full-featured production image
    ├── robotics-image.bb              # Base robotics image
    ├── robotics-dev-image.bb          # Development image with tools
    └── robotics-qemu-image.bb         # Lightweight QEMU testing image
```

## 🖼️ Image Recipes Overview

### Base Images Hierarchy

```text
core-image (Yocto base class)
    ├── robotics-image.bb              (Base robotics functionality)
    │   ├── robotics-controller-image.bb   (Enhanced production image)
    │   └── robotics-dev-image.bb          (Development tools added)
    └── robotics-qemu-image.bb         (QEMU-optimized lightweight)
```

## 📋 Image Descriptions

### 1. `robotics-image.bb` - Base Robotics Image

**Purpose**: Minimal robotics controller image with essential functionality

**Key Features**:

- ✅ Core robotics controller application
- ✅ OpenCV computer vision library
- ✅ Python 3 with OpenCV bindings
- ✅ Hardware interface tools (I2C, SPI, GPIO)
- ✅ systemd init system
- ✅ SSH server for remote access
- ✅ Basic development tools (gdb, strace)

**Target Use**: Production deployment, minimal footprint systems

**Package Highlights**:

```bitbake
robotics-controller     # Main controller application
opencv                  # Computer vision
python3-opencv          # Python CV bindings
i2c-tools              # I2C bus utilities
spi-tools              # SPI interface tools
gpio-utils             # GPIO control utilities
systemd                # Modern init system
openssh                # Remote access
```

### 2. `robotics-controller-image.bb` - Enhanced Production Image

**Purpose**: Full-featured robotics image with comprehensive toolset

**Key Features**:

- ✅ All features from robotics-image.bb
- ✅ Extended package set for production use
- ✅ Additional development conveniences
- ✅ Enhanced debugging capabilities
- ✅ USB and connectivity tools
- ✅ Text editors and utilities

**Target Use**: Production systems requiring full toolset, field deployment

**Additional Packages**:

```bitbake
usbutils               # USB device management
libgpiod-tools         # Advanced GPIO tools
opencv-samples         # OpenCV examples
connman                # Network connectivity
busybox                # Essential utilities
vim                    # Advanced text editor
htop                   # System monitoring
git                    # Version control
cmake                  # Build system
```

**Image Features**:

- Debug support with symbols
- SDK tools included
- SSH server enabled
- 512MB extra rootfs space for development

### 3. `robotics-dev-image.bb` - Development Image

**Purpose**: Development-focused image with comprehensive toolchain

**Key Features**:

- ✅ Inherits all robotics-image.bb functionality
- ✅ Complete C/C++ development toolchain
- ✅ Kernel development support
- ✅ Performance analysis tools
- ✅ Hardware debugging utilities

**Target Use**: Active development, debugging, performance tuning

**Development Tools**:

```bitbake
# Compilation Tools
cmake, gcc, g++, make, pkgconfig

# Version Control & Editors
git, vim

# Debugging & Analysis
gdb, valgrind, perf, strace

# Kernel Development
kernel-dev, kernel-devsrc

# Hardware Tools
devmem2, iozone3, bonnie++, ldd
```

### 4. `robotics-qemu-image.bb` - QEMU Testing Image

**Purpose**: Lightweight image optimized for QEMU virtualization and testing

**Key Features**:

- ✅ Minimal footprint for fast boot
- ✅ Core robotics functionality
- ✅ Essential debugging tools
- ✅ QEMU environment detection
- ✅ Virtual hardware optimization

**Target Use**: Development testing, CI/CD, algorithm validation

**QEMU Optimizations**:

- Lightweight package selection
- Fast boot configuration
- Virtual environment detection
- 512MB extra space for testing
- Environment variables for runtime detection

## 🚀 Usage Guide

### Building Images

#### For Production Deployment

```bash
# Build the enhanced production image
bitbake robotics-controller-image

# Or build the minimal base image
bitbake robotics-image
```

#### For Development

```bash
# Build development image with all tools
bitbake robotics-dev-image
```

#### For QEMU Testing

```bash
# Build lightweight QEMU image
bitbake robotics-qemu-image

# Run in QEMU
runqemu robotics-qemu-image
```

### Customizing Images

#### Adding Packages

To add packages to any image, modify the `IMAGE_INSTALL` variable:

```bitbake
# In your bbappend file or local.conf
IMAGE_INSTALL:append = " your-package another-package"
```

#### Creating Custom Images

Create a new `.bb` file that requires an existing image:

```bitbake
# custom-robotics-image.bb
DESCRIPTION = "Custom Robotics Image"
LICENSE = "MIT"

# Base on existing image
require robotics-controller-image.bb

# Add custom packages
IMAGE_INSTALL:append = " \
    your-custom-package \
    additional-tools \
"
```

## 🎯 Platform Compatibility

| Image | BeagleBone Black | Raspberry Pi 4 | QEMU | Use Case |
|-------|------------------|----------------|------|----------|
| robotics-image | ✅ | ✅ | ✅ | Production base |
| robotics-controller-image | ✅ | ✅ | ⚠️ | Enhanced production |
| robotics-dev-image | ✅ | ✅ | ⚠️ | Active development |
| robotics-qemu-image | N/A | N/A | ✅ | Testing only |

**Legend**: ✅ Optimized | ⚠️ Functional but large | N/A Not applicable

## 🔧 Configuration Options

### Image Features

Each image supports these optional features via `IMAGE_FEATURES`:

- `debug-tweaks` - Development conveniences (empty root password, etc.)
- `tools-debug` - Debugging tools and utilities
- `tools-sdk` - Software development kit
- `dev-pkgs` - Development packages and headers
- `ssh-server-openssh` - OpenSSH server
- `dbg-pkgs` - Debug symbol packages

### Security Considerations

#### Production Deployment

- Change default root password (currently set to "robotics")
- Remove `debug-tweaks` feature
- Disable unnecessary services
- Configure secure SSH access

#### Development vs Production

```bitbake
# Development configuration
IMAGE_FEATURES += "debug-tweaks tools-debug"

# Production configuration  
EXTRA_USERS_PARAMS = "usermod -P your-secure-password root;"
# Remove debug-tweaks
```

## 📊 Image Size Comparison

| Image | Approximate Size | Boot Time | Memory Usage |
|-------|------------------|-----------|--------------|
| robotics-image | ~200MB | Fast | Low |
| robotics-controller-image | ~400MB | Moderate | Medium |
| robotics-dev-image | ~600MB | Slower | High |
| robotics-qemu-image | ~150MB | Very Fast | Very Low |

## 🛠️ Troubleshooting

### Common Issues

#### Build Failures

```bash
# Clean specific image
bitbake -c cleanall robotics-controller-image

# Rebuild
bitbake robotics-controller-image
```

#### Package Conflicts

Check for conflicting packages in `IMAGE_INSTALL` lists and ensure proper package dependencies.

#### Large Image Size

Consider using robotics-image.bb as base and selectively adding only required packages.

### Debugging Tips

1. **Check package dependencies**:

   ```bash
   bitbake-layers show-recipes | grep robotics
   ```

2. **Verify image contents**:

   ```bash
   bitbake robotics-controller-image -e | grep ^IMAGE_INSTALL=
   ```

3. **Test in QEMU first**:

   ```bash
   runqemu robotics-qemu-image
   ```

## 🔄 Development Workflow

### Recommended Workflow

1. **Algorithm Development**: Use `robotics-qemu-image` for rapid testing
2. **Hardware Integration**: Test with `robotics-dev-image` on target hardware  
3. **Production Deployment**: Build and deploy `robotics-controller-image`

### Image Selection Guide

- **Starting development?** → `robotics-qemu-image`
- **Need hardware debugging?** → `robotics-dev-image`
- **Production deployment?** → `robotics-controller-image`
- **Minimal footprint needed?** → `robotics-image`

## 📚 Related Documentation

- [Meta-Robotics Configuration Guide](../conf/README.md)
- [Build System Documentation](../../docs/build-guide.md)
- [Hardware Setup Guide](../../docs/hardware-setup.md)
- [Troubleshooting Guide](../../docs/troubleshooting.md)

---

**Note**: These images are part of the meta-robotics Yocto layer. Ensure your build environment is properly configured before building any images.
