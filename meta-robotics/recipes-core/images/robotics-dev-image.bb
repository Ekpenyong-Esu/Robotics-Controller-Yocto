DESCRIPTION = "Robotics Controller Development Image"
LICENSE = "MIT"

# Base robotics image
require robotics-image.bb

# Development packages
IMAGE_INSTALL:append = " \
    cmake \
    gcc \
    g++ \
    make \
    pkgconfig \
    git \
    vim \
    gdb \
    valgrind \
    perf \
    kernel-dev \
    kernel-devsrc \
"

# Tools for hardware debugging
IMAGE_INSTALL:append = " \
    devmem2 \
    iozone3 \
    bonnie++ \
    ldd \
    file \
    which \
"
