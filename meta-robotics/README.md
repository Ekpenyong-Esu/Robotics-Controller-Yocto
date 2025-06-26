# Meta-Robotics Yocto Layer

## 🚀 Overview

This is a comprehensive Yocto Project layer that provides a complete robotics controller platform for embedded systems. It transforms standard hardware like BeagleBone Black and Raspberry Pi 4 into powerful robotics controllers with real-time capabilities, optimized device drivers, and a complete application stack.

## 🏗️ Architecture Overview

The meta-robotics layer implements a **layered architecture** that builds upon the standard Yocto/OpenEmbedded foundation:

```text
┌─────────────────────────────────────────────────────────────┐
│                  ROBOTICS APPLICATIONS                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Robotics Control│  │  Web Interface  │  │   Sensors   │ │
│  │   Application   │  │     (HTTP)      │  │   Drivers   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    LINUX USERSPACE                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │    systemd      │  │    OpenCV       │  │   Python    │ │
│  │   (Service)     │  │  (Vision AI)    │  │ (Scripting) │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                 REAL-TIME LINUX KERNEL                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │  RT-PREEMPT     │  │  Device Tree    │  │   Drivers   │ │
│  │  (Real-time)    │  │ (HW Interface)  │  │ (I2C/SPI)   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                      HARDWARE LAYER                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ BeagleBone Black│  │ Raspberry Pi 4  │  │    QEMU     │ │
│  │   (Production)  │  │ (Development)   │  │  (Testing)  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Complete Directory Structure

```text
meta-robotics/
├── README.md                           # This comprehensive guide
│
├── conf/                               # 🔧 Layer & Machine Configuration
│   ├── README.md                       # Configuration documentation
│   ├── layer.conf                      # Layer metadata and dependencies
│   ├── machine/                        # Hardware-specific configurations
│   │   ├── beaglebone-robotics.conf    # BeagleBone Black optimizations
│   │   ├── rpi4-robotics.conf          # Raspberry Pi 4 optimizations
│   │   └── qemu-robotics.conf          # QEMU virtual testing
│   └── templates/                      # Build configuration templates
│       ├── bblayers.conf              # Layer configuration template
│       ├── local.conf                 # Build settings template
│       ├── beaglebone-config/          # BeagleBone-specific templates
│       │   ├── local.conf             # BeagleBone build configuration
│       │   └── bblayers.conf          # BeagleBone layer configuration
│       └── qemu-config/                # QEMU-specific templates
│           ├── local.conf             # QEMU build configuration
│           └── bblayers.conf          # QEMU layer configuration
│
├── recipes-core/                       # 🖼️ System Images & Core Modifications
│   ├── README.md                       # Image recipes documentation
│   └── images/                         # Bootable system images
│       ├── robotics-image.bb           # Base robotics functionality
│       ├── robotics-controller-image.bb # Enhanced production image
│       ├── robotics-dev-image.bb       # Development toolchain image
│       └── robotics-qemu-image.bb      # Lightweight testing image
│
├── recipes-kernel/                     # 🐧 Linux Kernel Customizations
│   └── linux/                          # Kernel modifications
│       ├── linux-yocto-rt_%.bbappend   # Real-time kernel extensions
│       ├── linux-raspberrypi-rt_%.bbappend # RPi-specific kernel mods
│       └── linux-yocto-rt/             # Kernel configuration files
│           ├── README.md                # Kernel customization guide
│           ├── 0001-Add-BeagleBone-Black-robotics-dts.patch # Device tree
│           ├── robotics-platform.cfg   # Core robotics kernel config
│           ├── robotics-platform-rpi.cfg # RPi-specific kernel config
│           ├── rt-preemption.cfg        # Real-time scheduling config
│           ├── gpio.cfg                 # GPIO subsystem config
│           ├── i2c.cfg                  # I2C bus configuration
│           ├── spi.cfg                  # SPI interface configuration
│           ├── pwm.cfg                  # PWM (motor control) config
│           └── v4l2.cfg                 # Video4Linux (camera) config
│
└── recipes-robotics/                   # 🤖 Robotics-Specific Applications
    └── robotics-controller/            # Main controller application
        ├── robotics-controller_1.0.bb  # Application build recipe
        └── files/                       # Application configuration files
            ├── robotics-controller.service # systemd service definition
            ├── robotics-controller-init    # Initialization script
            └── robotics-controller.conf    # Runtime configuration
```

## 🔗 Component Relationships & Data Flow

### 1. **Build-Time Integration Flow**

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   conf/         │───▶│  recipes-kernel/ │───▶│  recipes-core/  │
│ (Configuration) │    │ (Kernel Build)   │    │ (Image Build)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         │                        ▼                        ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         └─────────────▶│recipes-robotics/│───▶│  Final Images   │
                        │ (App Package)   │    │ (.wic, .tar.gz) │
                        └─────────────────┘    └─────────────────┘
```

### 2. **Runtime System Integration**

```text
System Boot ──▶ Kernel (RT) ──▶ systemd ──▶ robotics-controller.service
     │              │              │              │
     ▼              ▼              ▼              ▼
Device Tree ──▶ Drivers ──▶ Hardware ──▶ Application APIs
(GPIO/I2C)    (Sensors)   (Physical)    (Robot Control)
```

## 🎯 Component Details & Purpose

### **conf/ - Configuration Foundation**

**Purpose**: Defines the build environment, target hardware, and layer relationships

**Key Components**:
- **`layer.conf`**: Declares layer metadata, dependencies, and compatibility
- **Machine configs**: Hardware-specific optimizations (CPU, memory, peripherals)
- **Templates**: Pre-configured build environments for different use cases

**How it links**: Used by BitBake at the start of every build to understand:
- What hardware we're targeting
- Which other layers are needed
- What build optimizations to apply

### **recipes-kernel/ - Linux Kernel Customization**

**Purpose**: Extends the standard Linux kernel with real-time capabilities and robotics-specific drivers

**Key Components**:

#### **Real-Time Extensions** (`rt-preemption.cfg`):
```bash
CONFIG_PREEMPT_RT=y          # Enable real-time preemption
CONFIG_HIGH_RES_TIMERS=y     # Microsecond-precision timing
CONFIG_NO_HZ_FULL=y          # Tickless operation for RT cores
```

#### **Hardware Interface Drivers**:
- **GPIO** (`gpio.cfg`): Digital I/O for sensors and actuators
- **I2C** (`i2c.cfg`): Communication bus for sensors (IMU, ToF)
- **SPI** (`spi.cfg`): High-speed bus for precision sensors
- **PWM** (`pwm.cfg`): Motor control and servo positioning
- **V4L2** (`v4l2.cfg`): Camera interfaces for computer vision

#### **Device Tree Patches**:
The BeagleBone device tree patch (`0001-Add-BeagleBone-Black-robotics-dts.patch`) configures:
```dts
/* Enable I2C1 for sensors */
&i2c1 {
    vl53l0x@29 {              // Time-of-Flight distance sensor
        compatible = "st,vl53l0x";
        reg = <0x29>;
    };
};

/* Enable PWM for motor control */
&ehrpwm1 {
    pinctrl-0 = <&robotics_pwm_pins>;  // Motor control pins
};
```

**How it links**: The kernel configurations are applied during kernel compilation, creating a real-time capable kernel with all robotics peripherals enabled.

### **recipes-core/ - System Images**

**Purpose**: Combines all components into bootable system images for different use cases

**Image Hierarchy**:
```text
core-image (base) ──┬── robotics-image.bb (minimal)
                    ├── robotics-controller-image.bb (production)
                    ├── robotics-dev-image.bb (development)
                    └── robotics-qemu-image.bb (testing)
```

**Package Integration**:
Each image includes specific packages:
- **Base**: `robotics-controller`, `opencv`, `python3`
- **Production**: + USB tools, connectivity, debugging
- **Development**: + GCC toolchain, kernel sources, profiling tools
- **QEMU**: Minimal for fast testing and CI/CD

**How it links**: Images pull packages from recipes-robotics and use the kernel from recipes-kernel, creating complete bootable systems.

### **recipes-robotics/ - Application Layer**

**Purpose**: Builds and packages the main robotics controller application

**Components**:

#### **Main Application** (`robotics-controller_1.0.bb`):
- Builds C++ robotics control software
- Integrates with OpenCV for computer vision
- Provides web interface for remote control
- Handles sensor fusion and motor control

#### **Service Integration** (`robotics-controller.service`):
```ini
[Unit]
Description=Robotics Controller Service
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/robotics-controller-init
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### **Configuration Management**:
- **`robotics-controller-init`**: Startup script with hardware detection
- **`robotics-controller.conf`**: Runtime parameters (PID gains, sensor calibration)

**How it links**: The application is packaged and installed by the image recipes, configured to start automatically via systemd, and uses the kernel drivers for hardware access.

## 🔄 Build Process Flow

### **1. Configuration Phase**
```bash
# BitBake reads layer.conf to understand dependencies
DEPENDS = "meta-openembedded meta-oe meta-python"

# Machine configuration sets hardware parameters
MACHINE = "beaglebone-robotics"
DISTRO_FEATURES += "systemd opencv"
```

### **2. Kernel Build Phase**
```bash
# Kernel recipe applies our configurations
linux-yocto-rt_%.bbappend
├── Applies rt-preemption.cfg (real-time kernel)
├── Applies robotics-platform.cfg (I2C, SPI, GPIO drivers)
├── Applies device tree patch (hardware pinmux)
└── Creates: bzImage + devicetree.dtb
```

### **3. Application Build Phase**
```bash
# Application recipe builds from source
robotics-controller_1.0.bb
├── Compiles C++ source code
├── Links with OpenCV libraries
├── Installs systemd service files
└── Creates: robotics-controller package
```

### **4. Image Assembly Phase**
```bash
# Image recipe combines everything
robotics-controller-image.bb
├── Takes kernel from recipes-kernel/
├── Takes apps from recipes-robotics/
├── Adds base packages (systemd, opencv, python3)
└── Creates: .wic (bootable), .tar.gz (rootfs)
```

## 🎛️ Hardware Integration Points

### **BeagleBone Black Integration**

The layer configures specific hardware interfaces:

```text
Physical Hardware    ──▶  Device Tree   ──▶  Kernel Driver  ──▶  Application API
├── GPIO Pins        ──▶  gpio_pins     ──▶  gpio-keys      ──▶  /sys/class/gpio/
├── I2C Bus          ──▶  i2c1_pins     ──▶  i2c-omap       ──▶  /dev/i2c-1
├── SPI Bus          ──▶  spi0_pins     ──▶  spi-omap2      ──▶  /dev/spidev0.0
├── PWM Outputs      ──▶  pwm_pins      ──▶  ehrpwm         ──▶  /sys/class/pwm/
└── ADC Inputs       ──▶  tscadc        ──▶  ti_am335x_adc  ──▶  /sys/bus/iio/
```

### **Sensor Integration Example**

For a Time-of-Flight sensor on I2C:

1. **Device Tree** defines hardware connection:
   ```dts
   vl53l0x@29 {
       compatible = "st,vl53l0x";
       reg = <0x29>;
   };
   ```

2. **Kernel Config** enables I2C driver:
   ```bash
   CONFIG_I2C_OMAP=y
   CONFIG_VL53L0X=m
   ```

3. **Application** accesses via Linux API:
   ```cpp
   int fd = open("/dev/i2c-1", O_RDWR);
   ioctl(fd, I2C_SLAVE, 0x29);
   ```

## 🚀 Usage Workflows

### **Development Workflow**
```bash
# 1. Setup build environment
source oe-init-build-env

# 2. Configure for development
MACHINE="beaglebone-robotics" bitbake robotics-dev-image

# 3. Test in QEMU first
bitbake robotics-qemu-image
runqemu robotics-qemu-image

# 4. Deploy to hardware
dd if=robotics-dev-image.wic of=/dev/sdX
```

### **Production Deployment**
```bash
# 1. Configure for production
MACHINE="beaglebone-robotics" bitbake robotics-controller-image

# 2. Flash to eMMC
dd if=robotics-controller-image.wic of=/dev/mmcblk1
```

### **Customization Workflow**
```bash
# 1. Modify application
edit recipes-robotics/robotics-controller/files/src/main.cpp

# 2. Add kernel features
echo "CONFIG_NEW_SENSOR=y" >> recipes-kernel/linux/linux-yocto-rt/sensors.cfg

# 3. Rebuild
bitbake robotics-controller-image
```

## 🔧 Configuration Options

### **Machine Selection**
- **`beaglebone-robotics`**: Production BeagleBone Black
- **`rpi4-robotics`**: Development Raspberry Pi 4
- **`qemu-robotics`**: Virtual testing environment

### **Image Variants**
- **`robotics-image`**: Minimal robotics base (200MB)
- **`robotics-controller-image`**: Full production system (400MB)
- **`robotics-dev-image`**: Development with toolchain (600MB)
- **`robotics-qemu-image`**: Lightweight testing (150MB)

### **Feature Toggles**
```bash
# In local.conf
DISTRO_FEATURES += "systemd opencv python"  # Enable features
MACHINE_FEATURES += "gpio i2c spi pwm"      # Hardware interfaces
IMAGE_FEATURES += "debug-tweaks tools-sdk"  # Development tools
```

## 🛠️ Troubleshooting & Maintenance

### **Common Build Issues**

1. **Missing Dependencies**:
   ```bash
   ERROR: Nothing PROVIDES 'opencv'
   # Solution: Add meta-openembedded layers
   ```

2. **Kernel Config Conflicts**:
   ```bash
   WARNING: CONFIG_RT_PREEMPT not set
   # Solution: Check rt-preemption.cfg inclusion
   ```

3. **Device Tree Errors**:
   ```bash
   ERROR: DTC: /tmp/am335x-boneblack-robotics.dts:45.1-7 syntax error
   # Solution: Validate device tree syntax
   ```

### **Debugging Tools**

```bash
# Check layer dependencies
bitbake-layers show-layers

# Verify kernel config
bitbake virtual/kernel -c menuconfig

# Test device tree
fdtdump /boot/devicetree.dtb

# Monitor application
systemctl status robotics-controller
journalctl -u robotics-controller -f
```

## 📚 Related Documentation

- **[Configuration Guide](conf/README.md)** - Layer and machine configuration details
- **[Image Recipes Guide](recipes-core/README.md)** - System image creation and customization
- **[Kernel Customization](recipes-kernel/linux/linux-yocto-rt/README.md)** - Real-time kernel modifications
- **[Build System Guide](../../docs/build-guide.md)** - Complete build instructions
- **[Hardware Setup](../../docs/hardware-setup.md)** - Physical hardware configuration

## 🎯 Quick Start

```bash
# 1. Clone and setup
git clone <repository>
cd Robotics-Controller-Yocto
source setup-yocto-env.sh

# 2. Build for BeagleBone
export MACHINE=beaglebone-robotics
bitbake robotics-controller-image

# 3. Flash and boot
dd if=tmp/deploy/images/beaglebone-robotics/robotics-controller-image.wic of=/dev/sdX
# Insert SD card and power on BeagleBone
```

---

**Note**: This meta-robotics layer provides a complete robotics platform. All components are designed to work together seamlessly, from hardware drivers through the application layer, creating a production-ready robotics controller system.

## Using This Layer

### Adding to Your Build

1. Clone this repository
2. Add the layer to your `bblayers.conf`:

   ```bash
   BBLAYERS += "/path/to/meta-robotics"
   ```

3. Set your machine in `local.conf`:

   ```bash
   MACHINE ?= "beaglebone-robotics"
   ```

### Building an Image

```bash
# Initialize build environment
source oe-init-build-env

# Build the robotics image
bitbake robotics-image
```

## Key Components

| Component | Description |
|-----------|-------------|
| Real-time Kernel | Linux with PREEMPT_RT for low-latency control |
| Device Drivers | I2C, SPI, GPIO, PWM, and V4L2 for hardware access |
| OpenCV | Computer vision libraries for image processing |
| Custom DTB | Custom device tree for robotics hardware |
| Robotics Controller | Main application controlling all robotics functions |

## For Beginners

If you're new to Yocto, start with:

1. Edit machine configuration (`conf/machine/*.conf`) to match your hardware
2. Modify kernel configurations in `recipes-kernel/linux`
3. Update the robotics-controller recipe as your application evolves

For BuildRoot users, the `beaglebone_robotics_defconfig` file serves a similar purpose as the combined Yocto machine config and recipes.
