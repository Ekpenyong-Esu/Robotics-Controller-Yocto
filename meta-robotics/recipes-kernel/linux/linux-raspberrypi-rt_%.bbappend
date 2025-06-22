FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Enable real-time features for Raspberry Pi 3 and 4
SRC_URI:append:raspberrypi3 = " \
    file://rt-preemption.cfg \
    file://robotics-platform-rpi.cfg \
"

SRC_URI:append:raspberrypi4 = " \
    file://rt-preemption.cfg \
    file://robotics-platform-rpi.cfg \
"

# Enable required modules for robotics
SRC_URI:append = " \
    file://i2c.cfg \
    file://spi.cfg \
    file://gpio.cfg \
    file://pwm.cfg \
    file://v4l2.cfg \
"
