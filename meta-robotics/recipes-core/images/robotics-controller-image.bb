SUMMARY = "Robotics Controller Image"
DESCRIPTION = "Custom image for robotics applications"
LICENSE = "MIT"

inherit core-image

# Base packages
IMAGE_INSTALL = " \
    packagegroup-core-boot \
    packagegroup-core-full-cmdline \
    packagegroup-core-ssh-openssh \
    kernel-modules \
    bash \
    nano \
    usbutils \
    i2c-tools \
    spitools \
    libgpiod \
    libgpiod-tools \
    python3 \
    python3-pip \
    opencv \
    opencv-samples \
    openssh \
    connman \
    connman-client \
    busybox \
    vim \
    robotics-controller \
"

# Development tools
IMAGE_FEATURES += " \
    debug-tweaks \
    tools-debug \
    tools-sdk \
    dev-pkgs \
    ssh-server-openssh \
"

# Extra space for development work
IMAGE_ROOTFS_EXTRA_SPACE = "512000"

# Enable remote debugging
EXTRA_IMAGE_FEATURES += "dbg-pkgs"

# For development convenience
CORE_IMAGE_EXTRA_INSTALL += "htop git cmake"
