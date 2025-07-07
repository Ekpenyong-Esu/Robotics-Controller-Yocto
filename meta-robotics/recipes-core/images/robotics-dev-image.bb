SUMMARY = "Robotics Controller Development Image"
DESCRIPTION = "Development image for robotics controller with debugging tools and development utilities."
LICENSE = "MIT"

# Base robotics image
require robotics-controller-image.bb

# Override image name for development variant
IMAGE_BASENAME = "robotics-controller-dev"

# =================================================================
# DEVELOPMENT TOOLS
# =================================================================
IMAGE_INSTALL:append = " \
    git \
    vim \
    nano \
    bash \
"

# =================================================================
# DEBUGGING AND TROUBLESHOOTING TOOLS
# =================================================================
IMAGE_INSTALL:append = " \
    strace \
    gdb \
    valgrind \
    perf \
"

# Add development image features (including debug access)
IMAGE_FEATURES:append = " \
    tools-debug \
    debug-tweaks \
    allow-empty-password \
    allow-root-login \
"

# Extra rootfs space for development
IMAGE_ROOTFS_EXTRA_SPACE = "262144"

# =================================================================
# DEVELOPMENT ENVIRONMENT SETUP
# =================================================================
dev_env_setup() {
    # Create directory structure
    install -d ${IMAGE_ROOTFS}/etc/profile.d
    install -d ${IMAGE_ROOTFS}/opt/robotics-dev

    # Create development environment script
    cat > ${IMAGE_ROOTFS}/etc/profile.d/dev-env.sh << 'EOF'
#!/bin/sh
# Development environment for robotics controller
export ROBOTICS_ENV="development"
export ROBOTICS_PLATFORM="embedded"

# Application paths
export ROBOTICS_CONTROLLER_WEB="/usr/share/robotics-controller/www"
export ROBOTICS_CONTROLLER_CONFIG="/etc/robotics-controller/robotics-controller.conf"

echo "Robotics Controller Development Environment"
echo "Web interface: $ROBOTICS_CONTROLLER_WEB"
echo "Configuration: $ROBOTICS_CONTROLLER_CONFIG"
EOF
    chmod 755 ${IMAGE_ROOTFS}/etc/profile.d/dev-env.sh

    # Create development README
    cat > ${IMAGE_ROOTFS}/opt/robotics-dev/README.txt << 'EOF'
Robotics Controller Development Environment
==========================================

Components:
- C++ robotics controller: /usr/bin/robotics-controller
- Web interface: /usr/share/robotics-controller/www/
- Configuration: /etc/robotics-controller/robotics-controller.conf
- Service: systemctl status robotics-controller

Development:
- Source code available in build environment
- Debugging tools installed
- Hardware interfaces enabled

Commands:
- systemctl start robotics-controller
- i2cdetect -y 1
- gpiodetect
EOF
}

ROOTFS_POSTPROCESS_COMMAND += "dev_env_setup; "
