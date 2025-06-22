# Robotics Controller Kernel Configuration

This directory contains Linux kernel configuration fragments and device tree patches specifically designed for robotics applications. Each file serves a specific purpose in enabling hardware interfaces and real-time capabilities required for robotics control systems.

## 📁 Directory Contents

### Device Tree Patches
- `0001-Add-BeagleBone-Black-robotics-dts.patch` - BeagleBone Black hardware enablement

### Core Kernel Configuration Files
- `rt-preemption.cfg` - Real-time preemption for deterministic timing
- `gpio.cfg` - GPIO interface for sensors, LEDs, and buttons
- `i2c.cfg` - I2C bus for sensor communication
- `spi.cfg` - SPI interface for high-speed devices
- `pwm.cfg` - PWM for motor and servo control
- `v4l2.cfg` - Video4Linux2 for camera support

### Platform-Specific Configuration
- `robotics-platform.cfg` - BeagleBone Black specific optimizations
- `robotics-platform-rpi.cfg` - Raspberry Pi 4 specific optimizations

## 🔧 Configuration Files Detailed Guide

### Real-Time Preemption (`rt-preemption.cfg`)

**Purpose**: Enables PREEMPT_RT patches for hard real-time performance required in robotics applications.

**Key Features**:
- Deterministic interrupt latency
- High-resolution timers for precise timing
- Real-time scheduling policies
- Reduced kernel latency

**When to Use**: Essential for applications requiring precise timing such as:
- Motor control loops
- Sensor sampling at fixed intervals
- Real-time communication protocols
- Safety-critical systems

### GPIO Configuration (`gpio.cfg`)

**Purpose**: Enables GPIO interfaces for digital I/O operations.

**Hardware Supported**:
- Digital sensors (limit switches, encoders)
- LEDs for status indication
- Push buttons for user input
- General-purpose digital I/O

**Interfaces Enabled**:
- `/sys/class/gpio` - Sysfs GPIO interface
- `/dev/gpiochipX` - Character device interface
- GPIO interrupt support

### I2C Configuration (`i2c.cfg`)

**Purpose**: Enables I2C bus communication for sensor integration.

**Typical Devices**:
- IMU sensors (accelerometer, gyroscope, magnetometer)
- Environmental sensors (temperature, humidity, pressure)
- Distance sensors (ultrasonic, time-of-flight)
- Display modules
- Real-time clocks

**Features**:
- Multi-master support
- Clock stretching
- 7-bit and 10-bit addressing
- BeagleBone I2C controller support

### SPI Configuration (`spi.cfg`)

**Purpose**: Enables high-speed SPI communication for performance-critical devices.

**Typical Devices**:
- High-precision IMU sensors
- ADC/DAC converters
- Flash memory devices
- High-speed communication modules

**Features**:
- Master mode operation
- Multiple chip select support
- Configurable clock rates
- Full-duplex communication

### PWM Configuration (`pwm.cfg`)

**Purpose**: Enables Pulse Width Modulation for motor and actuator control.

**Applications**:
- DC motor speed control
- Servo motor positioning
- LED brightness control
- Buzzer/speaker control

**Features**:
- Multiple PWM channels
- Configurable frequency and duty cycle
- Hardware-based PWM generation
- Sysfs interface for userspace control

### Video4Linux2 Configuration (`v4l2.cfg`)

**Purpose**: Enables camera and video device support for computer vision applications.

**Supported Devices**:
- USB cameras (UVC compatible)
- CSI camera modules
- Video capture devices
- V4L2 compatible devices

**Features**:
- Multiple pixel formats
- Frame rate control
- Resolution selection
- Video streaming support

## 🏗️ Platform-Specific Configurations

### BeagleBone Black (`robotics-platform.cfg`)

**Hardware Features Enabled**:
- **PRU (Programmable Real-time Unit)**: For ultra-low latency I/O operations
- **Industrial I/O (IIO)**: For ADC and sensor data acquisition
- **TI-specific drivers**: Optimized for AM335x processor

**Use Cases**:
- Real-time motor control using PRU
- Analog sensor reading via ADC
- Custom timing-critical operations

### Raspberry Pi 4 (`robotics-platform-rpi.cfg`)

**Hardware Features Enabled**:
- **VideoCore GPU support**: For hardware-accelerated video processing
- **Broadcom-specific drivers**: Optimized for BCM2711 processor
- **Firmware interface**: For hardware configuration

**Use Cases**:
- Computer vision applications
- Hardware-accelerated image processing
- Raspberry Pi-specific peripherals

## 🚀 How to Use These Configurations

### 1. Building with Yocto

The configuration files are automatically included when building the robotics controller image:

```bash
# Build the robotics image (includes all configs)
bitbake robotics-image

# Build BeagleBone-specific image
MACHINE=beaglebone-robotics bitbake robotics-image

# Build Raspberry Pi-specific image  
MACHINE=rpi4-robotics bitbake robotics-image
```

### 2. Adding New Configuration Options

To add custom kernel configurations:

1. **Create a new .cfg file**:
   ```bash
   # Example: custom-sensor.cfg
   echo "# Custom sensor support" > custom-sensor.cfg
   echo "CONFIG_CUSTOM_SENSOR=y" >> custom-sensor.cfg
   ```

2. **Update the kernel recipe** to include your config:
   ```bitbake
   # In linux-yocto-rt_%.bbappend
   SRC_URI:append = " file://custom-sensor.cfg"
   ```

### 3. Kernel Configuration Best Practices

**Configuration Principles**:
- ✅ Enable only required features to minimize kernel size
- ✅ Use modules for optional features that can be loaded on demand
- ✅ Separate platform-specific configs from generic ones
- ✅ Document the purpose of each configuration option

**Testing Configurations**:
```bash
# Check if config was applied
zcat /proc/config.gz | grep CONFIG_OPTION

# List available kernel modules
lsmod

# Check hardware detection
dmesg | grep -i "driver_name"
```

## 🔍 Device Tree Patch Details

### BeagleBone Black Robotics Device Tree

**File**: `0001-Add-BeagleBone-Black-robotics-dts.patch`

**Hardware Configuration**:
- **GPIO Assignments**:
  - Status LED: GPIO1_13 (Pin P8.11)
  - Control Button: GPIO1_19 (Pin P9.14)
  
- **Interface Pin Assignments**:
  - I2C1: UART0_CTSN/RTSN pins (dedicated, no conflicts)
  - SPI0: SPI0_SCLK/D0/D1/CS0 pins (dedicated)
  - PWM: GPMC_A2/A3 for motor control
  - UART1: For GPS module communication

**Sensors Enabled**:
- VL53L0X Time-of-Flight sensor (I2C address 0x29)
- MPU-9250 IMU sensor (SPI device)
- 8-channel ADC for analog sensors

## 🛠️ Troubleshooting

### Common Issues and Solutions

**Issue**: GPIO not accessible
```bash
# Solution: Check if GPIO driver is loaded
lsmod | grep gpio
# Enable GPIO sysfs if needed
echo "gpio" > /sys/class/gpio/export
```

**Issue**: I2C device not detected
```bash
# Solution: Scan I2C bus
i2cdetect -y 1
# Check device tree configuration
cat /sys/firmware/devicetree/base/compatible
```

**Issue**: Real-time performance issues
```bash
# Solution: Check RT kernel
uname -a | grep PREEMPT_RT
# Monitor interrupt latency
cyclictest -p 80 -t5 -w -m -n
```

## 📋 Configuration Summary

| Feature | Config File | Hardware | Use Case |
|---------|-------------|----------|----------|
| Real-time | `rt-preemption.cfg` | CPU scheduler | Motor control, timing |
| GPIO | `gpio.cfg` | Digital I/O | LEDs, buttons, sensors |
| I2C | `i2c.cfg` | Sensor bus | IMU, environmental sensors |
| SPI | `spi.cfg` | High-speed bus | Precision sensors, ADCs |
| PWM | `pwm.cfg` | Motor control | Servos, DC motors |
| Camera | `v4l2.cfg` | Video devices | Computer vision |
| Platform | `robotics-platform*.cfg` | Specific hardware | Platform optimization |

This configuration set provides a complete foundation for robotics applications with proper hardware abstraction and real-time capabilities.
