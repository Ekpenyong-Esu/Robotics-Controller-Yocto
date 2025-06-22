# Hardware Setup Guide

## BeagleBone Black Hardware Configuration

### Pin Assignments

#### I2C Interfaces

- **I2C1**: `/dev/i2c-1` - IMU (MPU-9250), Distance sensor (VL53L0X)
  - Pin P9.17: SCL
  - Pin P9.18: SDA

#### SPI Interfaces  

- **SPI0**: `/dev/spidev0.0` - Additional sensors (if needed)
  - Pin P9.22: SCLK
  - Pin P9.21: MISO  
  - Pin P9.18: MOSI
  - Pin P9.17: CS0

#### UART Interfaces

- **UART1**: `/dev/ttyS1` - GPS Module
  - Pin P9.24: TX
  - Pin P9.26: RX

#### PWM Outputs (Motor Control)

- **PWM1A**: Pin P9.14 - Left Motor Speed Control
- **PWM1B**: Pin P9.16 - Right Motor Speed Control

#### GPIO Pins

- **Motor Direction Control**:
  - Pin P8.7 (GPIO 66): Left Motor Direction
  - Pin P8.8 (GPIO 67): Right Motor Direction
  
- **IR Sensors** (Line Following):
  - Pin P8.9 (GPIO 69): Left IR Sensor
  - Pin P8.10 (GPIO 68): Center IR Sensor  
  - Pin P8.11 (GPIO 45): Right IR Sensor

- **Buttons/Switches**:
  - Pin P8.12 (GPIO 44): Emergency Stop Button
  - Pin P8.13 (GPIO 23): Mode Selection Button

#### ADC Inputs

- **ADC_AIN0**: Pin P9.39 - Battery Voltage Monitor (voltage divider)
- **ADC_AIN1**: Pin P9.40 - Additional Analog Sensor
- **ADC_AIN2**: Pin P9.37 - Line Sensor Array Input
- **ADC_AIN3**: Pin P9.38 - Light Sensor/Ambient Light

#### USB Interface

- **USB Host**: Camera module connection
- **USB Device**: Programming and debugging

### Required Hardware Components

#### Core Components

1. **BeagleBone Black Rev C** (or newer)
2. **MicroSD Card** (8GB minimum, Class 10)
3. **5V Power Supply** (2A minimum)

#### Sensors

1. **MPU-9250** - 9-axis IMU (I2C)
   - 3-axis accelerometer, gyroscope, magnetometer
   - Address: 0x68 or 0x69

2. **VL53L0X** - Time-of-Flight Distance Sensor (I2C)
   - Range: 30mm to 2000mm
   - Address: 0x29

3. **GPS Module** - UART compatible (e.g., NEO-6M, NEO-8M)
   - Baud rate: 9600
   - NMEA protocol support

4. **IR Sensors** - Digital line following sensors
   - TCRT5000 or similar
   - Digital output (GPIO compatible)

5. **USB Camera** - Computer vision processing
   - UVC compatible (plug-and-play)
   - Minimum 640x480 resolution

#### Motor Control

1. **Motor Driver** - H-Bridge compatible
   - L298N or similar dual H-bridge
   - PWM speed control
   - GPIO direction control

2. **DC Motors** - Gear motors with encoders (optional)
   - 12V or compatible with power supply
   - Encoder feedback for closed-loop control

#### Power Management

1. **Voltage Regulator** - 12V to 5V conversion
   - For BeagleBone Black power
   - 2A minimum current capability

2. **Battery Pack** - 12V lithium or NiMH
   - Capacity: 2000mAh minimum
   - Built-in protection circuit recommended

### Wiring Diagrams

#### I2C Bus Wiring

```
BeagleBone Black    MPU-9250    VL53L0X
P9.17 (SCL)    ->   SCL     ->  SCL
P9.18 (SDA)    ->   SDA     ->  SDA
3.3V           ->   VCC     ->  VIN
GND            ->   GND     ->  GND
```

#### Motor Control Wiring

```
BeagleBone Black    L298N Motor Driver
P9.14 (PWM1A)  ->   ENA (Left Motor Speed)
P9.16 (PWM1B)  ->   ENB (Right Motor Speed)
P8.7  (GPIO66) ->   IN1 (Left Motor Dir 1)
P8.8  (GPIO67) ->   IN2 (Left Motor Dir 2)
P8.9  (GPIO69) ->   IN3 (Right Motor Dir 1)
P8.10 (GPIO68) ->   IN4 (Right Motor Dir 2)
```

#### GPS Module Wiring

```
BeagleBone Black    GPS Module
P9.24 (UART1_TX) -> RX
P9.26 (UART1_RX) -> TX
3.3V             -> VCC
GND              -> GND
```

### Software Prerequisites

#### Enable Interfaces

Add to `/boot/uEnv.txt`:

```bash
# Enable I2C
dtb_overlay=BB-I2C1

# Enable PWM
dtb_overlay=BB-PWM1

# Enable UART
dtb_overlay=BB-UART1
```

#### Device Tree Overlays

Ensure the following overlays are loaded:

- `BB-I2C1-00A0.dtbo` - I2C1 interface
- `BB-PWM1-00A0.dtbo` - PWM outputs
- `BB-UART1-00A0.dtbo` - UART1 interface

### Testing Hardware

#### I2C Device Detection

```bash
i2cdetect -y -r 1
```

Expected output should show devices at:

- 0x68 or 0x69 (MPU-9250)
- 0x29 (VL53L0X)

#### GPIO Testing

```bash
# Export GPIO pin
echo 66 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio66/direction

# Test output
echo 1 > /sys/class/gpio/gpio66/value
echo 0 > /sys/class/gpio/gpio66/value
```

#### PWM Testing

```bash
# Navigate to PWM directory
cd /sys/class/pwm/pwmchip0

# Export PWM channel
echo 0 > export

# Configure PWM
echo 20000000 > pwm0/period    # 20ms period (50Hz)
echo 1000000 > pwm0/duty_cycle # 1ms pulse width
echo 1 > pwm0/enable
```

#### UART Testing

```bash
# Check UART device
ls -l /dev/ttyS1

# Test communication (install minicom)
minicom -D /dev/ttyS1 -b 9600
```

### Troubleshooting

#### Common Issues

1. **I2C devices not detected**
   - Check wiring connections
   - Verify 3.3V power supply
   - Ensure pull-up resistors (usually built-in)
   - Check device tree overlay loading

2. **PWM not working**
   - Verify PWM overlay is loaded
   - Check pin configuration in device tree
   - Ensure no pin conflicts with other peripherals

3. **UART communication issues**
   - Verify baud rate settings
   - Check TX/RX wiring (not crossed)
   - Ensure UART overlay is loaded
   - Check for serial console conflicts

4. **GPIO access denied**
   - Run as root or add user to gpio group
   - Check udev rules for GPIO access
   - Verify pin is not used by other services

5. **Camera not recognized**
   - Check USB connection
   - Verify camera is UVC compatible
   - Install v4l-utils: `apt install v4l-utils`
   - Test with: `v4l2-ctl --list-devices`

### Performance Optimization

#### CPU Governor

Set performance governor for real-time operation:

```bash
echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

#### Real-time Scheduling

Configure real-time priorities in systemd service:

```ini
[Service]
CPUSchedulingPolicy=1
CPUSchedulingPriority=50
```

#### Memory Management

- Disable swap: `swapoff -a`
- Set kernel parameters for low latency
- Increase CMA memory for camera operations

### Safety Considerations

1. **Emergency Stop**
   - Hardware emergency stop button required
   - Software watchdog implementation
   - Motor disable on communication loss

2. **Power Management**
   - Battery voltage monitoring
   - Automatic shutdown on low battery
   - Surge protection for power supply

3. **Thermal Management**
   - Monitor CPU temperature
   - Thermal throttling protection
   - Adequate ventilation for continuous operation

4. **Mechanical Safety**
   - Secure mounting of all components
   - Protection for rotating parts
   - Collision detection and avoidance
