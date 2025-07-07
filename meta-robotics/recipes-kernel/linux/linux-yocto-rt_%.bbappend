# =================================================================
# LINUX KERNEL RECIPE APPEND FILE
# =================================================================
# This file extends the Linux kernel recipe for the real-time (RT) variant
# The "%" in the filename matches any version of linux-yocto-rt
# =================================================================

# Allow this kernel recipe to build for all robotics machines
COMPATIBLE_MACHINE:append = "|qemu-robotics|beaglebone-robotics|rpi3-robotics|rpi4-robotics"

# Add our custom files to the search path for kernel configs
# FILESEXTRAPATHS allows Yocto to find our custom files in the recipe directory
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# =================================================================
# REAL-TIME KERNEL CONFIGURATION
# =================================================================
# These configs are only applied to the BeagleBone machine
# rt-preemption.cfg - Enables PREEMPT_RT for real-time operation
# robotics-platform.cfg - Platform-specific optimizations for robotics
# spi-beaglebone.cfg - BeagleBone-specific SPI hardware drivers
# =================================================================
SRC_URI:append:beaglebone-robotics = " \
    file://rt-preemption.cfg \
    file://robotics-platform.cfg \
    file://spi-beaglebone.cfg \
"

# =================================================================
# HARDWARE INTERFACES CONFIGURATION
# =================================================================
# These kernel configs are applied to all machines
# Each .cfg file enables kernel support for a specific I/O interface:
# - i2c.cfg: I2C bus for sensors (IMU, distance sensors, etc.)
# - spi.cfg: SPI interface for high-speed peripherals
# - gpio.cfg: GPIO for digital inputs/outputs
# - pwm.cfg: PWM for motor and servo control
# - v4l2.cfg: Video4Linux2 for camera interfaces
# =================================================================
SRC_URI:append = " \
    file://i2c.cfg \
    file://spi.cfg \
    file://gpio.cfg \
    file://pwm.cfg \
    file://v4l2.cfg \
"

# =================================================================
# DEVICE TREE CUSTOMIZATIONS
# =================================================================
# Apply our custom Device Tree patch for BeagleBone Black
# This adds our robotics-specific pin configurations, enabling:
# - Motor control pins
# - Sensor interfaces
# - Additional hardware features required by the robotics controller
# =================================================================
SRC_URI:append:beaglebone-robotics = " \
    file://0001-Add-BeagleBone-Black-robotics-dts.patch \
"

# =================================================================
# RASPBERRY PI ROBOTICS PLATFORM CONFIGURATION
# =================================================================
# Apply Raspberry Pi-specific robotics kernel config with RT support
# This enables hardware features, optimizations, and real-time capabilities for RPi robotics
# =================================================================
SRC_URI:append:rpi3-robotics = " \
    file://rt-preemption.cfg \
    file://robotics-platform-rpi.cfg \
"
SRC_URI:append:rpi4-robotics = " \
    file://rt-preemption.cfg \
    file://robotics-platform-rpi.cfg \
"
