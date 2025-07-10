#!/bin/bash

# Test script for QEMU login verification
# This script helps verify the QEMU image login configuration

echo "=========================================="
echo "QEMU Login Test Script"
echo "=========================================="

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/output"

# Check if output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory not found: $OUTPUT_DIR"
    echo "Please build the image first:"
    echo "  cd $PROJECT_ROOT"
    echo "  scripts/build.sh"
    exit 1
fi

# Look for image files with correct naming
IMAGE_FILE=""
if [ -f "$OUTPUT_DIR/rootfs.ext4" ]; then
    IMAGE_FILE="$OUTPUT_DIR/rootfs.ext4"
    echo "Found convenience image: rootfs.ext4"
elif [ -f "$OUTPUT_DIR/robotics-controller-image-qemu-robotics.rootfs.ext4" ]; then
    IMAGE_FILE="$OUTPUT_DIR/robotics-controller-image-qemu-robotics.rootfs.ext4"
    echo "Found named image: robotics-controller-image-qemu-robotics.rootfs.ext4"
else
    # Look for any .ext4 file in output directory
    EXT4_FILES=($(find "$OUTPUT_DIR" -name "*.ext4" -type f))
    if [ ${#EXT4_FILES[@]} -gt 0 ]; then
        IMAGE_FILE="${EXT4_FILES[0]}"
        echo "Found image file: $(basename "$IMAGE_FILE")"
    else
        echo "Error: No QEMU image (.ext4) files found in $OUTPUT_DIR"
        echo ""
        echo "Available files in output directory:"
        ls -la "$OUTPUT_DIR" 2>/dev/null || echo "  (directory empty or not accessible)"
        echo ""
        echo "Please build the QEMU image first:"
        echo "  cd $PROJECT_ROOT"
        echo "  scripts/build.sh --machine qemu-robotics --image robotics-qemu-image"
        exit 1
    fi
fi

# Check for kernel file
KERNEL_FILE=""
if [ -f "$OUTPUT_DIR/kernel" ]; then
    KERNEL_FILE="$OUTPUT_DIR/kernel"
elif [ -f "$OUTPUT_DIR/Image" ]; then
    KERNEL_FILE="$OUTPUT_DIR/Image"
else
    echo "Warning: No kernel file found in output directory"
    echo "QEMU launch may fail without kernel file"
fi

echo ""
echo "Login Test Information:"
echo "======================"
echo "Image file: $(basename "$IMAGE_FILE")"
[ -n "$KERNEL_FILE" ] && echo "Kernel file: $(basename "$KERNEL_FILE")"
echo ""
echo "Expected login options:"
echo "1. Username: root, Password: root"
echo "2. Username: root, Password: (empty - just press Enter)"
echo ""
echo "After login, you should see:"
echo "- QEMU environment information"
echo "- Robotics platform: qemu"
echo "- Available commands and tools"
echo ""
echo "Test commands to try after login:"
echo "- robotics-qemu-info.sh"
echo "- systemctl status robotics-controller"
echo "- cat /etc/robotics-platform"
echo "- cat /opt/robotics-qemu/README.txt"
echo ""

# Function to launch QEMU with proper options
launch_qemu() {
    echo "Launching QEMU image..."
    echo "Image: $(basename "$IMAGE_FILE")"
    echo "Press Ctrl+A, then X to exit QEMU"
    echo ""
    
    # Try runqemu first (preferred method)
    if command -v runqemu >/dev/null 2>&1; then
        echo "Using runqemu to launch image..."
        cd "$PROJECT_ROOT/build"
        
        # Check if we can determine the correct image name
        if [[ "$(basename "$IMAGE_FILE")" == *"qemu"* ]]; then
            runqemu qemu-robotics robotics-qemu-image nographic
        else
            runqemu qemu-robotics nographic
        fi
    else
        echo "runqemu not available, using direct QEMU command..."
        
        if [ -z "$KERNEL_FILE" ]; then
            echo "Error: Kernel file required for direct QEMU launch"
            echo "Please ensure kernel file is available in output directory"
            exit 1
        fi
        
        qemu-system-aarch64 \
            -machine virt \
            -cpu cortex-a57 \
            -m 1024 \
            -nographic \
            -kernel "$KERNEL_FILE" \
            -drive file="$IMAGE_FILE",format=raw,id=hd0 \
            -netdev user,id=net0 \
            -device virtio-net-device,netdev=net0 \
            -append "root=/dev/vda rw console=ttyAMA0"
    fi
}

# Check if convenience launch script exists
if [ -f "$OUTPUT_DIR/launch-qemu.sh" ]; then
    echo "Convenience launch script available: $OUTPUT_DIR/launch-qemu.sh"
    echo ""
fi

# Ask user if they want to launch QEMU
echo "Do you want to launch QEMU now to test login? (y/n)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    launch_qemu
else
    echo ""
    echo "Manual launch options:"
    echo "====================="
    echo ""
    echo "Option 1 - Using convenience script (if available):"
    echo "  cd $OUTPUT_DIR"
    echo "  ./launch-qemu.sh"
    echo ""
    echo "Option 2 - Using runqemu from build directory:"
    echo "  cd $PROJECT_ROOT/build"
    echo "  runqemu qemu-robotics robotics-qemu-image nographic"
    echo ""
    echo "Option 3 - Direct QEMU command:"
    if [ -n "$KERNEL_FILE" ]; then
        echo "  qemu-system-aarch64 -machine virt -cpu cortex-a57 -m 1024 -nographic \\"
        echo "    -kernel $(basename "$KERNEL_FILE") -drive file=$(basename "$IMAGE_FILE"),format=raw,id=hd0 \\"
        echo "    -netdev user,id=net0 -device virtio-net-device,netdev=net0 \\"
        echo "    -append 'root=/dev/vda rw console=ttyAMA0'"
    else
        echo "  (kernel file required - not found in output directory)"
    fi
fi

echo ""
echo "Login troubleshooting:"
echo "====================="
echo "If login fails, try these approaches:"
echo "1. Username: root, Password: root"
echo "2. Username: root, Password: (empty - just press Enter)"
echo "3. Check QEMU console for boot messages and errors"
echo "4. Verify image built successfully:"
echo "   - Check build logs in: $PROJECT_ROOT/build/tmp-glibc/log/"
echo "   - Verify image recipe: meta-robotics/recipes-core/images/robotics-qemu-image.bb"
echo "5. Check extrausers configuration in image recipe"
echo ""
echo "To rebuild with login fixes:"
echo "  cd $PROJECT_ROOT"
echo "  scripts/clean.sh --output    # Clean output directory"
echo "  scripts/build.sh --clean     # Clean build and rebuild"
echo ""
echo "Build information:"
echo "  Build directory: $PROJECT_ROOT/build"
echo "  Output directory: $OUTPUT_DIR"
echo "  Image file: $IMAGE_FILE"
[ -n "$KERNEL_FILE" ] && echo "  Kernel file: $KERNEL_FILE"
