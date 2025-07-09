SUMMARY = "Robotics Controller QEMU Testing Image"
DESCRIPTION = "QEMU-compatible image for testing the robotics controller web interface. \
Minimal testing environment without hardware-specific dependencies."
LICENSE = "MIT"

require robotics-controller-image.bb

IMAGE_BASENAME = "robotics-qemu-image"

inherit extrausers

# Simple: Allow root login with empty password for QEMU testing
EXTRA_USERS_PARAMS = "usermod -p '' root;"

# Add QEMU-specific packages for testing
IMAGE_INSTALL:append = " \
    packagegroup-core-ssh-openssh \
    bash \
    openssh \
    python3-json \
"

# Remove hardware-specific packages not available in QEMU
IMAGE_INSTALL:remove = " \
"

IMAGE_FEATURES:append = " \
    tools-debug \
    tools-profile \
    package-management \
    allow-root-login \
    empty-root-password \
"

IMAGE_ROOTFS_EXTRA_SPACE = "131072"

qemu_env_setup() {
    install -d ${IMAGE_ROOTFS}/etc/profile.d
    cat > ${IMAGE_ROOTFS}/etc/profile.d/qemu-env.sh << 'EOF'
#!/bin/sh
export QEMU_ENV=1
export ROBOTICS_ENV="virtual"
export ROBOTICS_PLATFORM="qemu"
export ROBOTICS_CONTROLLER_WEB="/usr/share/robotics-controller/www"
export ROBOTICS_CONTROLLER_CONFIG="/etc/robotics-controller/robotics-controller.conf"

echo "Running in QEMU virtual environment"
echo "Robotics Controller Web Interface Testing"
echo "- Web files: $ROBOTICS_CONTROLLER_WEB"
echo "- Configuration: $ROBOTICS_CONTROLLER_CONFIG"
echo "- Test web interface: python3 -m http.server 8080 -d $ROBOTICS_CONTROLLER_WEB"
echo ""
echo "Login Information:"
echo "- Username: root"
echo "- Password: (just press Enter - no password needed)"
EOF
    chmod 755 ${IMAGE_ROOTFS}/etc/profile.d/qemu-env.sh


    echo "qemu-development" > ${IMAGE_ROOTFS}/etc/robotics-platform

    install -d ${IMAGE_ROOTFS}/etc/robotics-controller
    cat > ${IMAGE_ROOTFS}/etc/robotics-controller/qemu.conf << 'EOF'
[platform]
type=qemu
simulation_mode=true

[hardware]
gpio_enabled=false
i2c_enabled=false
spi_enabled=false
can_enabled=false

[web]
bind_address=0.0.0.0
port=8080
debug_mode=true

[logging]
level=debug
console_output=true
EOF

    install -d ${IMAGE_ROOTFS}/usr/local/bin
    cat > ${IMAGE_ROOTFS}/usr/local/bin/robotics-qemu-info.sh << 'EOF'
#!/bin/bash
echo "================================================"
echo "Robotics Controller - QEMU Development Environment"
echo "================================================"
echo "Platform: $(cat /etc/robotics-platform)"
echo "Application: /usr/bin/robotics-controller"
echo "Web Interface: $ROBOTICS_CONTROLLER_WEB"
echo "Configuration: $ROBOTICS_CONTROLLER_CONFIG"
echo "QEMU Config: /etc/robotics-controller/qemu.conf"
echo ""
echo "Login Information:"
echo "  Username: root"
echo "  Password: (just press Enter - no password needed)"
echo ""
echo "Service Commands:"
echo "  systemctl start robotics-controller"
echo "  systemctl status robotics-controller"
echo "  systemctl stop robotics-controller"
echo ""
echo "Development Commands:"
echo "  journalctl -u robotics-controller -f  # Follow logs"
echo "  gdb /usr/bin/robotics-controller      # Debug"
echo "================================================"
EOF
    chmod 755 ${IMAGE_ROOTFS}/usr/local/bin/robotics-qemu-info.sh

    install -d ${IMAGE_ROOTFS}/opt/robotics-qemu
    cat > ${IMAGE_ROOTFS}/opt/robotics-qemu/README.txt << 'EOF'
QEMU Robotics Development Environment
====================================
Login Information:
- Username: root
- Password: (just press Enter - no password needed)

Main Application:
- Binary: /usr/bin/robotics-controller
- Web Interface: /usr/share/robotics-controller/www/
- Configuration: /etc/robotics-controller.conf
- QEMU Config: /etc/robotics-controller/qemu.conf
- Service: robotics-controller.service

QEMU-Specific Features:
- Hardware simulation mode enabled
- Debug logging enabled
- Web interface on port 8080
- All hardware interfaces simulated

Development Tools:
- robotics-qemu-info.sh - Display system info
- gdb - Debug the application
- strace - Trace system calls
- valgrind - Memory debugging

Testing:
1. Start service: systemctl start robotics-controller
2. Check status: systemctl status robotics-controller
3. View logs: journalctl -u robotics-controller -f
4. Access web: http://localhost:8080 (if port forwarded)

Troubleshooting Login Issues:
- Try username 'root' and just press Enter (no password)
- If that fails, check console output for errors
- Check if SSH is running: systemctl status ssh
- For serial console: Use QEMU monitor console

Environment Variables:
- QEMU_ENV=1
- ROBOTICS_ENV=virtual
- ROBOTICS_PLATFORM=qemu
- ROBOTICS_CONTROLLER_WEB=/usr/share/robotics-controller/www
- ROBOTICS_CONTROLLER_CONFIG=/etc/robotics-controller.conf
EOF
}

ROOTFS_POSTPROCESS_COMMAND += "qemu_env_setup; "

IMAGE_FSTYPES = "ext4 tar.xz"

QEMU_TARGETS = "arm"
