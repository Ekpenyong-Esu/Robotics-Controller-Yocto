
# Robotics Controller Application Recipe
# Installs the C++ backend and web interface for robotics controller

SUMMARY = "Robotics Controller Application"
DESCRIPTION = "Robotics controller with C++ backend and web interface."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Source repository and additional files
SRC_URI =  "git://git@github.com/Ekpenyong-Esu/Robotics-Controller-Yocto-Src.git;protocol=ssh;branch=master file://robotics-controller.service file://robotics-controller-init file://robotics-controller.conf"
SRCREV = "${AUTOREV}"
PV = "1.0+git${SRCPV}"
S = "${WORKDIR}/git/src"

# Build and runtime dependencies
DEPENDS = "cmake-native libgpiod nlohmann-json opencv"
RDEPENDS:${PN} = "libgpiod python3-core python3-json systemd opencv"

# Inherit CMake and systemd support
inherit cmake systemd
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "robotics-controller.service"
SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE_DIR ?= "${nonarch_libdir}/systemd/system"
systemd_system_unitdir ?= "${SYSTEMD_SERVICE_DIR}"

# Files to include in the package
FILES:${PN} += " \
    ${bindir}/robotics-controller \
    ${sysconfdir}/robotics-controller/* \
    ${datadir}/${PN}/www/* \
    ${systemd_system_unitdir}/robotics-controller.service \
"

# Install procedure
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

    # Install systemd service if enabled
    if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
        install -d ${D}${systemd_system_unitdir}
        install -m 0644 ${WORKDIR}/robotics-controller.service ${D}${systemd_system_unitdir}/
    fi
}
