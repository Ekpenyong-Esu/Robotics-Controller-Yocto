# Dual Development Workflow Quick Start

This guide explains how to use the dual development environment for both learning and real hardware implementation.

## Initial Setup

First, make sure all the necessary scripts are executable:

```bash
chmod +x scripts/dual-env.sh
```

## Getting Started

### 1. Check Available Environments

```bash
./scripts/dual-env.sh status
```

This will show you the status of all build environments (QEMU, BeagleBone, and RPi4).

### 2. Set Up QEMU Environment for Learning

```bash
./scripts/dual-env.sh setup qemu
```

This creates a separate build directory optimized for QEMU development.

### 3. Build the QEMU Image

```bash
./scripts/dual-env.sh build qemu
```

This builds a lightweight image suitable for testing in QEMU.

### 4. Run QEMU for Testing

```bash
./scripts/dual-env.sh run
```

This launches the QEMU virtual machine with networking support.

### 5. Set Up Hardware Environment

```bash
# For BeagleBone Black:
./scripts/dual-env.sh setup beaglebone

# For Raspberry Pi 4:
./scripts/dual-env.sh setup rpi4
```

### 6. Build the Hardware Image

```bash
# For BeagleBone Black:
./scripts/dual-env.sh build beaglebone

# For Raspberry Pi 4:
./scripts/dual-env.sh build rpi4
```

## Development Workflow

1. **Start with QEMU**: Develop and test core functionality in QEMU
2. **Simulate Hardware**: Use conditional code to simulate hardware interfaces in QEMU
3. **Test on Hardware**: Deploy to physical hardware for full testing
4. **Iterate**: Make improvements based on real-world feedback

## Common Tasks

### Clean a Build Environment

```bash
./scripts/dual-env.sh clean qemu
```

### Switch to Another Build Target

Simply run the setup command for your desired target:

```bash
./scripts/dual-env.sh setup beaglebone
```

### Run Specific BitBake Commands

After setting up an environment, you can run any BitBake command directly:

```bash
source poky/oe-init-build-env build-qemu
bitbake -c clean robotics-controller
```

## For More Information

See the detailed documentation in:
- `docs/dual-development-guide.md` - In-depth guide for dual development
- `docs/build-guide.md` - Complete build instructions for all targets

## Tips for Efficient Development

1. Use QEMU for rapid application development
2. Use hardware for interface testing and performance validation
3. Maintain separate Git branches for QEMU-specific code if needed
4. Create abstraction layers to adapt to both virtual and physical environments
