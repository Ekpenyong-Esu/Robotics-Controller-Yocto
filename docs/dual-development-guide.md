# Dual Development Approach for Robotics Controller

This guide outlines how to use both QEMU for learning/testing and physical hardware for deployment in your Robotics Controller project.

## Table of Contents
- [Learning with QEMU](#learning-with-qemu)
- [Deploying to Physical Hardware](#deploying-to-physical-hardware)
- [Alternating Between Environments](#alternating-between-environments)
- [Development Tips](#development-tips)

## Learning with QEMU

QEMU provides a virtual machine environment that lets you test your Yocto builds without physical hardware. This is perfect for learning and rapid development iterations.

### Setting Up QEMU Environment

```bash
# Switch to QEMU machine configuration
./scripts/change-machine.sh qemu

# Source the Yocto environment (if not already done)
source ./setup-yocto-env.sh

# Build a minimal image for testing
./scripts/build.sh
```

### Running in QEMU

After building, you can run your system in QEMU:

```bash
# Run QEMU with networking
runqemu qemux86-64 nographic slirp
```

### Benefits of QEMU Development

- **Fast iteration**: Rebuild and test quickly without flashing hardware
- **No hardware risks**: Test potentially dangerous operations safely
- **Debugging**: Easier access to debugging tools
- **Reproducible**: Same environment regardless of physical hardware
- **Resource efficient**: Can test while your physical build runs separately

## Deploying to Physical Hardware

Once your application works in QEMU, you can build for physical hardware.

### BeagleBone Black Deployment

```bash
# Switch to BeagleBone configuration
./scripts/change-machine.sh beaglebone

# Build the full robotics image
./scripts/build.sh
```

### Raspberry Pi Deployment

```bash
# Switch to Raspberry Pi configuration
./scripts/change-machine.sh rpi4

# Build the full robotics image
./scripts/build.sh
```

### Flashing Instructions

After building for physical hardware:

```bash
# For BeagleBone Black
./scripts/flash.sh --target bbb --device /dev/sdX

# For Raspberry Pi
./scripts/flash.sh --target rpi4 --device /dev/sdX
```

Replace `/dev/sdX` with your SD card device.

## Alternating Between Environments

### Using Separate Build Directories

To maintain both QEMU and hardware builds simultaneously:

```bash
# Create and use a QEMU-specific build directory
export TEMPLATECONF=${PWD}/meta-robotics/conf/templates/qemu-config
source poky/oe-init-build-env build-qemu

# In another terminal, create and use a hardware build directory
export TEMPLATECONF=${PWD}/meta-robotics/conf/templates/beaglebone-config
source poky/oe-init-build-env build-beaglebone
```

### Sharing Code Between Environments

For application development, follow these practices:

1. **Use runtime detection** in your applications to adapt to the platform
2. **Create abstraction layers** for hardware-specific functionality
3. **Use conditional compilation** for platform-specific code:

```c
#ifdef QEMU_BUILD
    // QEMU-specific simulation code
#else
    // Hardware-specific implementation
#endif
```

## Development Tips

### QEMU Development Workflow

1. **Start with QEMU** for rapid application development
2. **Use simulated interfaces** when physical hardware isn't available
3. **Enable extensive logging** to debug issues
4. **Create test cases** to verify functionality

### Testing Hardware Features

For hardware-specific features, create stubs in QEMU:

1. **GPIO simulation**: Use files or environment variables to simulate GPIO state
2. **Sensor data**: Generate simulated sensor readings
3. **Actuators**: Log commands instead of driving physical hardware

### Moving from QEMU to Hardware

When transitioning from QEMU to physical hardware:

1. **Start with small tests** to verify hardware interfaces
2. **Incrementally enable features** instead of all at once
3. **Watch for timing issues** that didn't appear in emulation
4. **Monitor resource usage** as real hardware may have constraints

### Example: Conditional Hardware Access

```python
import os

def control_motor(speed):
    if os.environ.get("QEMU_ENV") == "1":
        # In QEMU: Just log the command
        print(f"Motor would be set to speed: {speed}")
    else:
        # On hardware: Actually control the motor
        import hardware_control
        hardware_control.set_motor_speed(speed)
```

## Conclusion

Using both QEMU and physical hardware gives you the best of both worlds:
- Rapid development and learning with QEMU
- Full functionality testing on actual hardware

This approach accelerates development while ensuring your robotics controller works correctly on physical devices.
