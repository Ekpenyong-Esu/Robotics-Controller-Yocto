# =================================================================
# ROBOTICS CONTROLLER APPLICATION RECIPE
# =================================================================
# This recipe builds the main robotics controller application from source
# =================================================================

SUMMARY = "Robotics Controller Application"
DESCRIPTION = "Complete robotics controller with modular C++ backend and web-based interface. \
Features comprehensive sensor management, actuator control, communication systems, \
navigation engine, and computer vision capabilities."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# =================================================================
# SOURCE CODE LOCATION
# =================================================================
SRC_URI = "file://robotics-controller.service \
           file://robotics-controller-init \
           file://robotics-controller.conf \
          "

# Use the workspace source directly
S = "${TOPDIR}/../src"

# =================================================================
# DEPENDENCIES
# =================================================================
# Build dependencies for the C++ robotics controller
DEPENDS = "cmake-native libgpiod nlohmann-json opencv"

# Runtime dependencies
RDEPENDS:${PN} = "libgpiod python3-core python3-json systemd opencv"

# =================================================================
# BUILD SYSTEM
# =================================================================
inherit cmake systemd

# Systemd configuration
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "robotics-controller.service"
SYSTEMD_AUTO_ENABLE = "enable"

# Ensure systemd_system_unitdir is defined
SYSTEMD_SERVICE_DIR ?= "${nonarch_libdir}/systemd/system"
systemd_system_unitdir ?= "${SYSTEMD_SERVICE_DIR}"

# =================================================================
# FILE INSTALLATION
# =================================================================
FILES:${PN} += " \
    ${bindir}/robotics-controller \
    ${sysconfdir}/robotics-controller/* \
    ${datadir}/${PN}/www/* \
    ${systemd_system_unitdir}/robotics-controller.service \
"

# =================================================================
# INSTALLATION PROCEDURE
# =================================================================
do_install() {
    # Install the compiled binary
    install -d ${D}${bindir}
    install -m 0755 ${B}/robotics-controller/robotics-controller ${D}${bindir}/

    # Install configuration files
    install -d ${D}${sysconfdir}/robotics-controller
    install -m 0644 ${WORKDIR}/robotics-controller.conf ${D}${sysconfdir}/robotics-controller/

    # Install init script
    install -m 0755 ${WORKDIR}/robotics-controller-init ${D}${sysconfdir}/robotics-controller/

    # Install web interface files
    install -d ${D}${datadir}/${PN}/www
    install -m 0644 ${S}/web-interface/index.html ${D}${datadir}/${PN}/www/
    install -m 0644 ${S}/web-interface/script.js ${D}${datadir}/${PN}/www/
    install -m 0644 ${S}/web-interface/styles.css ${D}${datadir}/${PN}/www/
    install -m 0644 ${S}/web-interface/README.md ${D}${datadir}/${PN}/www/

    # Install systemd service
    if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
        install -d ${D}${systemd_system_unitdir}
        install -m 0644 ${WORKDIR}/robotics-controller.service ${D}${systemd_system_unitdir}/
    fi
}
