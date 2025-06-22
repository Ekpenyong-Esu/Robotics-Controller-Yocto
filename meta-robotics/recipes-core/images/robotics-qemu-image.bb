# QEMU Development Image Recipe
# Lighter version for rapid development and testing

SUMMARY = "Robotics Controller QEMU Testing Image"
DESCRIPTION = "Lightweight image for testing robotics controller in QEMU"

# Base this image on core-image-minimal from the base Yocto layer
inherit core-image

# Set the license
LICENSE = "MIT"

# Add image features for development
IMAGE_FEATURES += " \
    debug-tweaks \
    tools-debug \
    tools-sdk \
    ssh-server-openssh \
"

# Add testing packages (smaller set than the full robotics image)
IMAGE_INSTALL:append = " \
    robotics-controller \
    gdb \
    strace \
    htop \
    vim \
    nano \
    bash \
"

# Custom image name
IMAGE_BASENAME = "robotics-qemu-image"

# Add extra disk space for development
IMAGE_ROOTFS_EXTRA_SPACE = "512000"

# Add environment variable for runtime detection
qemu_env_setup() {
    # Create a script to set environment variables
    cat > ${IMAGE_ROOTFS}/etc/profile.d/qemu-env.sh << EOF
#!/bin/sh
# Identify QEMU environment
export QEMU_ENV=1
export ROBOTICS_ENV="virtual"
EOF
    chmod 755 ${IMAGE_ROOTFS}/etc/profile.d/qemu-env.sh
}

ROOTFS_POSTPROCESS_COMMAND += "qemu_env_setup;"
