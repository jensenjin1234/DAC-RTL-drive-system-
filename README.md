THS8200 FPGA Driver — 720p YCbCr Color-Bar Output

This repository contains an FPGA-based implementation for driving the Texas Instruments THS8200 video DAC.
The design generates a 720p@60Hz YCbCr color-bar output, configures all necessary THS8200 registers via I²C, and includes a modular RTL architecture suitable for FPGA lab projects or video pipeline demonstrations.

🚀 Features
✔ 720p@60Hz YCbCr Color-Bar Output

Generates industry-standard color bars

Compatible with most HDMI encoders via DAC

✔ Complete THS8200 Power-up & Register Configuration

Loads register table through I²C (400 kHz)

Initialization: sync polarity, color-space, timing registers

✔ Modular Verilog Architecture

Clean hierarchy for readability and debugging

Easy to extend or reuse for other video resolutions

📂 File Structure
File	Description
ths8200_top.v	Top-level integration module
ths8200_driver.v	THS8200 control logic
ths8200_init_ctrl.v	Init finite state machine (FSM)
ths8200_init_config.v	Lookup-table of THS8200 configuration values
iic_driver.v	I²C master controller
system_reset_top.v	Reset synchronization logic
system_parameter.v	Global parameters (resolution, clock)
system_delay.v	Generic delay module
sync_release.v	Sync signal release module
color_bayer_data.v	Generates raw color-bar test pattern
🏗 System Architecture
+-----------------------------+
|        ths8200_top         |
|                             |
|  +-----------------------+  |
|  |   ths8200_driver      |  |
|  |   - I2C init          |  |
|  |   - Timing config     |  |
|  +----------+------------+  |
|             |               |
|      +------+-------+       |
|      |  iic_driver  |       |
|      +--------------+       |
|                             |
|  +-----------------------+  |
|  |   color_bayer_data    |  |
|  +-----------------------+  |
+-----------------------------+

🛠 Requirements

FPGA board with THS8200 (or DAC-compatible output)

27 MHz / 74.25 MHz clock (depending on your board)

Vivado / Quartus / Diamond (or any Verilog tool)

🧪 Test Pattern Output

Standard SMPTE-style color bars

YCbCr 4:4:4 output formatting

All timing matches 1280×720 @ 60 Hz

📝 Author

Cheng Jin (Jensen)
FPGA / ASIC Digital Design • SystemVerilog • RTL Development
(Add your LinkedIn here if you want)
