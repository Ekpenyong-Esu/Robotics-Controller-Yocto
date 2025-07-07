SUMMARY = "Robotics Controller Production Image"
DESCRIPTION = "Production image for robotics controller with C++ backend and web interface. \
Optimized for embedded robotics applications with hardware control capabilities."
LICENSE = "MIT"

inherit core-image

# =================================================================
# CORE PACKAGES
# =================================================================
IMAGE_INSTALL = " \
    packagegroup-core-boot \
    systemd \
    python3-core \
    python3-json \
    robotics-controller \
    libgpiod-tools \
    util-linux \
    iproute2 \
"

# =================================================================
# HARDWARE CONTROL PACKAGES
# =================================================================
IMAGE_INSTALL:append = " \
    i2c-tools \
    kernel-modules \
"

# =================================================================
# DEVELOPMENT TOOLS (Optional - uncomment for debugging)
# =================================================================
# IMAGE_INSTALL:append = " \
#     packagegroup-core-ssh-openssh \
#     bash \
#     openssh \
#     nano \
#     vim \
#     strace \
#     gdb \
# "

# =================================================================
# SYSTEM CONFIGURATION
# =================================================================
# systemd configuration is handled in machine conf files
# (machine configurations handle init system selection)

# Image features for production (secure by default)
IMAGE_FEATURES += " ssh-server-openssh package-management "

# Production deployment - no empty passwords or root login
# For development, use robotics-dev-image.bb instead

# Add space for applications (512MB)
IMAGE_ROOTFS_EXTRA_SPACE = "524288"

# Set filesystem types
IMAGE_FSTYPES = "ext4 tar.bz2"
