SUMMARY = "Robotics Controller Development Image"
DESCRIPTION = "Development image for robotics controller with debugging tools and development utilities."
LICENSE = "MIT"

# Base robotics image

# Robotics Controller Development Image
# Extends the production image with development and debugging tools

SUMMARY = "Robotics Controller Development Image"
DESCRIPTION = "Development image for robotics controller with debugging tools and development utilities."
LICENSE = "MIT"

# Inherit base robotics production image
require robotics-controller-image.bb

# Set image name for development variant
IMAGE_BASENAME = "robotics-controller-dev"

# Add development tools
IMAGE_INSTALL:append = " git vim nano bash "

# Add debugging and troubleshooting tools
IMAGE_INSTALL:append = " strace gdb valgrind perf "

# Enable debug features and relaxed security for development
IMAGE_FEATURES:append = " tools-debug debug-tweaks allow-empty-password allow-root-login "

# Extra rootfs space for development (256MB)
IMAGE_ROOTFS_EXTRA_SPACE = "262144"

# Postprocess: Set up development environment and documentation
dev_env_setup() {
    # Create profile script for development environment
    install -d ${IMAGE_ROOTFS}/etc/profile.d
    cat > ${IMAGE_ROOTFS}/etc/profile.d/dev-env.sh << 'EOF'
#!/bin/sh
# Robotics Controller Development Environment
export ROBOTICS_ENV="development"
export ROBOTICS_PLATFORM="embedded"
export ROBOTICS_CONTROLLER_WEB="/usr/share/robotics-controller/www"
export ROBOTICS_CONTROLLER_CONFIG="/etc/robotics-controller/robotics-controller.conf"
echo "Robotics Controller Development Environment"
echo "Web interface: $ROBOTICS_CONTROLLER_WEB"
echo "Configuration: $ROBOTICS_CONTROLLER_CONFIG"
EOF
    chmod 755 ${IMAGE_ROOTFS}/etc/profile.d/dev-env.sh

    # Create development README
    install -d ${IMAGE_ROOTFS}/opt/robotics-dev
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
- Web interface: /usr/share/robotics-controller/www/
