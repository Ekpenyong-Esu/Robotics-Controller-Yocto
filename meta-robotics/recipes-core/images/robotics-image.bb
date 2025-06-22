DESCRIPTION = "Robotics Controller Linux Image"
LICENSE = "MIT"

# Base image - inherit core-image for minimal functionality
inherit core-image

# Essential robotics packages
IMAGE_INSTALL:append = " \
    robotics-controller \
    opencv \
    python3 \
    python3-opencv \
    i2c-tools \
    spi-tools \
    gpio-utils \
    systemd \
    systemd-networkd \
    openssh \
    htop \
    nano \
"

# Development tools (optional)
IMAGE_INSTALL:append = " \
    gdb \
    strace \
    tcpdump \
    iperf3 \
"

# Set root password (change in production)
EXTRA_USERS_PARAMS = "usermod -P robotics root;"

# Enable systemd
DISTRO_FEATURES:append = " systemd"
VIRTUAL-RUNTIME_init_manager = "systemd"
DISTRO_FEATURES_BACKFILL_CONSIDERED += "sysvinit"
VIRTUAL-RUNTIME_initscripts = ""

# Image features
IMAGE_FEATURES += "ssh-server-openssh"
