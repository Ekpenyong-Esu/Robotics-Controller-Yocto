
# Robotics Controller Linux Image
# General-purpose robotics image with essential and development tools

DESCRIPTION = "Robotics Controller Linux Image"
LICENSE = "MIT"

# Inherit Yocto core image class for minimal base
inherit core-image

# Essential robotics and system packages
IMAGE_INSTALL:append = " robotics-controller opencv python3 python3-opencv i2c-tools spi-tools gpio-utils systemd systemd-networkd openssh htop nano "

# Optional development and debugging tools
IMAGE_INSTALL:append = " gdb strace tcpdump iperf3 "

# Set root password (change for production deployments)
EXTRA_USERS_PARAMS = "usermod -P robotics root;"

# Enable systemd as init manager
DISTRO_FEATURES:append = " systemd"
VIRTUAL-RUNTIME_init_manager = "systemd"
DISTRO_FEATURES_BACKFILL_CONSIDERED += "sysvinit"
VIRTUAL-RUNTIME_initscripts = ""

# Enable SSH server for remote access
IMAGE_FEATURES += "ssh-server-openssh"
