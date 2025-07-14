
# Robotics Controller Production Image
# Minimal production image for robotics controller hardware

SUMMARY = "Robotics Controller Production Image"
DESCRIPTION = "Production image for robotics controller."
LICENSE = "MIT"

# Inherit Yocto core image class
inherit core-image

# Essential packages for robotics controller
IMAGE_INSTALL = "packagegroup-core-boot systemd python3-core python3-json robotics-controller libgpiod-tools util-linux iproute2 i2c-tools kernel-modules"

# Enable SSH and package management for remote access and updates
IMAGE_FEATURES += "ssh-server-openssh package-management"

# NOTE: For production, root login and empty passwords are disabled by default
# For development, use robotics-dev-image.bb instead


# Output filesystem types
IMAGE_FSTYPES = "ext4 tar.bz2"
