# Troubleshooting Guide

## System Startup Issues

### BeagleBone Black Won't Boot

#### Symptoms

- No activity LEDs
- No network connectivity
- No serial console output

#### Solutions

1. **Power Supply Issues**

   ```bash
   # Check power supply voltage
   # Should be 5V ±5% at 2A minimum
   ```

   - Verify power supply specification
   - Check barrel connector connection
   - Test with different power supply

2. **SD Card Issues**

   ```bash
   # Re-flash SD card image
   sudo dd if=sdcard.img of=/dev/sdX bs=1M status=progress
   sync
   ```

   - Use different SD card (Class 10, 8GB+)
   - Verify image integrity with checksum
   - Check SD card for corruption

3. **Hardware Faults**
   - Press and hold BOOT button while powering up
   - Check for physical damage
   - Verify all connections are secure

### Application Won't Start

#### Symptoms

- System boots but robotics controller service fails
- Error messages in system logs

#### Diagnosis

```bash
# Check service status
systemctl status robotics-controller

# View service logs
journalctl -u robotics-controller -f

# Check application logs
tail -f /var/log/robotics-controller.log
```

#### Common Solutions

1. **Permission Issues**

   ```bash
   # Fix GPIO permissions
   sudo usermod -a -G gpio robotics
   
   # Fix I2C permissions
   sudo usermod -a -G i2c robotics
   
   # Fix camera permissions
   sudo usermod -a -G video robotics
   ```

2. **Missing Dependencies**

   ```bash
   # Check for missing libraries
   ldd /usr/bin/robotics-controller
   
   # Install missing packages
   apt update && apt install libopencv-dev libgpiod-dev
   ```

3. **Device Tree Issues**

   ```bash
   # Check loaded overlays
   cat /proc/device-tree/model
   ls /sys/firmware/devicetree/base/__symbols__/
   
   # Reload device tree overlays
   echo BB-I2C1 > /sys/devices/platform/bone_capemgr/slots
   ```

## Sensor Issues

### I2C Devices Not Detected

#### Diagnosis

```bash
# Scan I2C bus
i2cdetect -y -r 1

# Expected output should show:
# 0x29 (VL53L0X distance sensor)
# 0x68 (MPU-9250 IMU)
```

#### Solutions

1. **Wiring Problems**
   - Check SDA/SCL connections (P9.17/P9.18)
   - Verify 3.3V power supply
   - Ensure common ground connection
   - Check for loose connections

2. **I2C Bus Issues**

   ```bash
   # Check I2C bus speed
   cat /sys/bus/i2c/devices/i2c-1/bus_clk_rate
   
   # Set slower speed if needed
   echo 100000 > /sys/bus/i2c/devices/i2c-1/bus_clk_rate
   ```

3. **Device Address Conflicts**

   ```bash
   # Some MPU-9250 modules use 0x69 instead of 0x68
   # Update sensor_manager.cpp if necessary
   ```

### GPS Not Working

#### Symptoms

- No GPS data in telemetry
- GPS status shows disconnected

#### Diagnosis

```bash
# Check UART device
ls -l /dev/ttyS1

# Test GPS communication
sudo minicom -D /dev/ttyS1 -b 9600
# Should see NMEA sentences like $GPGGA, $GPRMC
```

#### Solutions

1. **UART Configuration**

   ```bash
   # Check UART overlay
   cat /proc/device-tree/chosen/overlays/
   
   # Enable UART1 overlay
   echo BB-UART1 > /sys/devices/platform/bone_capemgr/slots
   ```

2. **GPS Module Issues**
   - Wait for GPS fix (can take several minutes)
   - Ensure antenna has clear sky view
   - Check 3.3V power supply to GPS module
   - Verify TX/RX wiring (not crossed)

3. **Baud Rate Mismatch**

   ```bash
   # Try different baud rates
   stty -F /dev/ttyS1 4800
   stty -F /dev/ttyS1 9600
   stty -F /dev/ttyS1 38400
   ```

### Camera Not Working

#### Symptoms

- Vision processor initialization fails
- No camera device detected

#### Diagnosis

```bash
# List video devices
v4l2-ctl --list-devices

# Test camera capture
ffmpeg -f v4l2 -i /dev/video0 -t 5 test.mp4
```

#### Solutions

1. **USB Issues**
   - Try different USB port
   - Check USB cable integrity
   - Verify camera power requirements

2. **Driver Issues**

   ```bash
   # Install v4l2 utilities
   apt install v4l-utils
   
   # Check camera capabilities
   v4l2-ctl -d /dev/video0 --all
   ```

3. **Permission Issues**

   ```bash
   # Add user to video group
   sudo usermod -a -G video robotics
   
   # Check device permissions
   ls -l /dev/video*
   ```

## Motor Control Issues

### Motors Not Responding

#### Symptoms

- No motor movement despite commands
- Motor driver gets hot
- Erratic motor behavior

#### Diagnosis

```bash
# Check PWM output
cat /sys/class/pwm/pwmchip*/pwm*/duty_cycle
cat /sys/class/pwm/pwmchip*/pwm*/period

# Check GPIO states
cat /sys/class/gpio/gpio66/value
cat /sys/class/gpio/gpio67/value
```

#### Solutions

1. **PWM Configuration**

   ```bash
   # Verify PWM overlays
   ls /lib/firmware/BB-PWM*
   
   # Check PWM frequency (50Hz = 20ms period)
   echo 20000000 > /sys/class/pwm/pwmchip0/pwm0/period
   ```

2. **Motor Driver Issues**
   - Check motor driver power supply (12V)
   - Verify enable pins are high
   - Check for thermal shutdown
   - Test with multimeter

3. **GPIO Direction Control**

   ```bash
   # Test GPIO manually
   echo 66 > /sys/class/gpio/export
   echo out > /sys/class/gpio/gpio66/direction
   echo 1 > /sys/class/gpio/gpio66/value
   ```

### Motor Speed Control Problems

#### Symptoms

- Motors run at constant speed
- No speed variation with PWM changes
- Motors stutter or jerk

#### Solutions

1. **PWM Signal Quality**

   ```bash
   # Check PWM frequency and duty cycle
   # Frequency should be 50-1000Hz for DC motors
   ```

2. **Motor Driver Compatibility**
   - Verify PWM signal levels (3.3V vs 5V)
   - Check motor driver PWM input requirements
   - Use level shifter if needed

3. **Power Supply Issues**
   - Check motor power supply voltage
   - Verify adequate current capacity
   - Monitor voltage drop under load

## Communication Issues

### Web Interface Not Accessible

#### Symptoms

- Cannot connect to robot's web interface
- Network connectivity issues

#### Diagnosis

```bash
# Check network interface
ip addr show

# Check web server
netstat -tlnp | grep 8080

# Test local connection
curl http://localhost:8080
```

#### Solutions

1. **Network Configuration**

   ```bash
   # Configure static IP (if needed)
   echo "auto eth0" >> /etc/network/interfaces
   echo "iface eth0 inet static" >> /etc/network/interfaces
   echo "address 192.168.1.100" >> /etc/network/interfaces
   echo "netmask 255.255.255.0" >> /etc/network/interfaces
   ```

2. **Firewall Issues**

   ```bash
   # Check iptables rules
   iptables -L
   
   # Allow port 8080
   iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
   ```

3. **Service Issues**

   ```bash
   # Restart networking
   systemctl restart networking
   
   # Restart robotics controller
   systemctl restart robotics-controller
   ```

### Remote Commands Not Working

#### Symptoms

- Web interface loads but commands don't execute
- Delayed response to commands

#### Solutions

1. **Command Processing**

   ```bash
   # Check application logs for command errors
   journalctl -u robotics-controller | grep command
   ```

2. **State Machine Issues**
   - Verify robot is not in emergency stop mode
   - Check manual override status
   - Ensure proper state transitions

## Performance Issues

### High CPU Usage

#### Symptoms

- System becomes sluggish
- Real-time performance degraded
- Thermal throttling

#### Diagnosis

```bash
# Monitor CPU usage
top -p $(pgrep robotics-controller)

# Check CPU frequency
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq

# Monitor temperature
cat /sys/class/thermal/thermal_zone0/temp
```

#### Solutions

1. **CPU Governor**

   ```bash
   # Set performance governor
   echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   ```

2. **Process Priority**

   ```bash
   # Increase process priority
   sudo renice -10 $(pgrep robotics-controller)
   ```

3. **Vision Processing Optimization**
   - Reduce camera resolution
   - Decrease frame rate
   - Optimize OpenCV algorithms

### Memory Issues

#### Symptoms

- Application crashes with out-of-memory errors
- System becomes unresponsive

#### Diagnosis

```bash
# Check memory usage
free -h
cat /proc/meminfo

# Monitor application memory
ps -p $(pgrep robotics-controller) -o pid,vsz,rss,comm
```

#### Solutions

1. **Memory Configuration**

   ```bash
   # Disable swap for real-time performance
   swapoff -a
   
   # Increase CMA memory for camera
   # Add to /boot/uEnv.txt:
   # cmdline=cma=128M
   ```

2. **Memory Optimization**
   - Reduce image buffer sizes
   - Optimize data structures
   - Implement memory pooling

## Error Codes and Messages

### Common Error Messages

#### "Failed to initialize sensor manager"

- Check I2C device connections
- Verify device tree overlays
- Check power supply to sensors

#### "Camera initialization failed"

- Verify USB camera connection
- Check camera permissions
- Install required video drivers

#### "GPS communication error"

- Check UART wiring and configuration
- Verify GPS module power
- Test with different baud rates

#### "Emergency stop activated"

- Check emergency stop button
- Verify system safety conditions
- Clear emergency state via web interface

#### "Navigation timeout"

- Check sensor data quality
- Verify line detection algorithms
- Adjust navigation parameters

### Log Analysis

#### Application Logs

```bash
# View real-time logs
tail -f /var/log/robotics-controller.log

# Search for specific errors
grep -i error /var/log/robotics-controller.log
grep -i warning /var/log/robotics-controller.log
```

#### System Logs

```bash
# Check kernel messages
dmesg | grep -i error

# Check system service logs
journalctl -u robotics-controller --since "1 hour ago"
```

## Recovery Procedures

### Emergency Recovery

1. **Hardware Emergency Stop**
   - Press emergency stop button
   - Disconnect motor power
   - Power cycle system

2. **Software Recovery**

   ```bash
   # Stop service
   sudo systemctl stop robotics-controller
   
   # Reset GPIO states
   echo 0 > /sys/class/gpio/gpio66/value
   echo 0 > /sys/class/gpio/gpio67/value
   
   # Restart service
   sudo systemctl start robotics-controller
   ```

### Factory Reset

1. **Application Reset**

   ```bash
   # Stop service
   sudo systemctl stop robotics-controller
   
   # Reset configuration
   rm -f /etc/robotics-controller/config.json
   
   # Restart service
   sudo systemctl start robotics-controller
   ```

2. **Full System Reset**
   - Re-flash SD card with original image
   - Reconfigure hardware connections
   - Restore application configuration

### Getting Help

#### Log Collection

```bash
# Collect system information
uname -a > system-info.txt
lsusb >> system-info.txt
lsmod >> system-info.txt
i2cdetect -y -r 1 >> system-info.txt

# Collect service logs
journalctl -u robotics-controller > service-logs.txt

# Collect application logs
cp /var/log/robotics-controller.log app-logs.txt
```

#### Support Information

- Hardware revision and part numbers
- Software version and build date
- Description of issue and steps to reproduce
- System logs and error messages
- Environmental conditions (temperature, power supply, etc.)
