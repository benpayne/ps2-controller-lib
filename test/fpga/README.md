# PS/2 Controller - Standalone FPGA Hardware Test

**Purpose**: Simple hardware test to verify PS/2 controller works on real FPGA hardware without needing a full CPU/SoC.

This is **Option B** - the prudent path to verify PS/2 hardware before integrating into complex systems like FemtoRV.

---

## What This Tests

- ✅ PS/2 keyboard connection and protocol
- ✅ PS/2 decoder core functionality
- ✅ Debouncing and synchronization
- ✅ FIFO buffering
- ✅ UART communication
- ❌ CPU integration (use FemtoRV test for that)

**Design**: Pure hardware - no CPU. PS/2 scan codes go directly to UART output.

---

## Hardware Requirements

1. **Colorlight i5 FPGA Board**
   - ECP5 FPGA (LFE5U-25F)
   - 25 MHz clock
   - 4 LEDs for status

2. **PS/2 Keyboard**
   - Standard PS/2 keyboard
   - OR USB keyboard with passive PS/2 adapter

3. **USB-to-Serial Adapter**
   - For viewing output (UART 115200 baud)

4. **Cables and Connectors**
   - Jumper wires for PS/2 connections
   - Optional: PS/2 breakout board or connector

---

## Pin Connections

### PS/2 Keyboard

| PS/2 Pin | Signal | FPGA Pin | Board Location |
|----------|--------|----------|----------------|
| 1 | Data | B3 | (see silkscreen) |
| 3 | GND | GND | Ground |
| 4 | VCC | 5V or 3.3V | Power |
| 5 | Clock | K5 | (see silkscreen) |

**PS/2 Connector Pinout** (looking at socket):
```
   ___
  /   \
 | 6 5 |    1=Data, 2=NC, 3=GND
 | 4 3 |    4=VCC, 5=Clock, 6=NC
  |2 1|
   ---
```

### UART (to Host PC)

| Signal | FPGA Pin | Description |
|--------|----------|-------------|
| TXD | J17 | FPGA transmits to host |

Connect to USB-to-Serial adapter RX pin.

### Status LEDs

| LED | FPGA Pin | Meaning |
|-----|----------|---------|
| LED1 | N18 | **Heartbeat** - Blinks at ~1.5 Hz to show FPGA is alive |
| LED2 | N17 | Interrupt (pulses briefly on new scan code) |
| LED3 | L20 | FIFO full (error - lights if FIFO overflows) |
| LED4 | M18 | Data ready (ON when scan code available in FIFO) |

**Important**: LED1 should blink continuously even without PS/2 keyboard connected. If LED1 doesn't blink, FPGA is not programmed or not running.

### Reset Button

- **Pin T1** (FIRE2 button on board)
- Press to reset the design

---

## Build Instructions

### Prerequisites

Install open-source FPGA tools:
```bash
# Yosys - Verilog synthesis
sudo apt install yosys

# nextpnr-ecp5 - Place and route
sudo apt install nextpnr-ecp5

# ecppack - Bitstream generation
sudo apt install ecppack

# openFPGALoader - Programming tool
sudo apt install openfpgaloader
```

### Build Steps

```bash
cd /opt/wip/ps2-controller-lib/test/fpga

# Build bitstream
make

# Expected output:
#   ✓ Synthesis complete
#   ✓ Place & route complete
#   ✓ Bitstream generated: ps2_test.bit
```

**Build time**: ~30 seconds (vs 2-3 minutes for full SoC)

**Resources**: ~200 LUTs (vs ~2800 for full FemtoRV SoC)

---

## Programming FPGA

### Option 1: Temporary Programming (RAM)

**Best for testing** - lost on power cycle:
```bash
make prog_fast
```

### Option 2: Permanent Programming (Flash)

**Survives power cycles**:
```bash
make prog
```

Both use `openFPGALoader` with CMSIS-DAP adapter.

---

## Testing

### 1. Connect Serial Terminal

You have two options:

**Option A: Python decoder (shows scan code names)**
```bash
# Install pyserial if not already installed
pip3 install pyserial
# Or: sudo apt-get install python3-serial

# Run decoder
./decode_ps2.py
```

**Option B: Simple hex viewer (no dependencies)**
```bash
./view_ps2_simple.sh
# Or specify port: ./view_ps2_simple.sh /dev/ttyUSB0
```

**Option C: Manual terminal (raw bytes)**
```bash
# Connect with screen
screen /dev/ttyUSB0 115200

# Or with minicom
minicom -D /dev/ttyUSB0 -b 115200
```

### 2. Power On / Press Reset

- Apply power to board
- OR press RESET button (T1 / FIRE2)

### 3. Observe LEDs

**At startup (before any keys pressed)**:
- **LED1** (heartbeat) should be **BLINKING** at ~1.5 Hz ← This proves FPGA is running!
- LED2, LED3, LED4 should be OFF

**When you press a key**:
  - **LED2** (interrupt) pulses briefly (~1 clock cycle, may be too fast to see)
  - **LED4** (data_ready) lights up and **STAYS ON** (until FIFO is read)
  - **LED1** continues blinking (heartbeat never stops)

### 4. Press Keys on Keyboard

Each key press sends **2 bytes** to UART:

**Byte 1: Status**
```
Bit 7-4: (unused)
Bit 3:   FIFO full flag
Bit 2:   ~data_ready (inverted)
Bit 1:   Interrupt flag
Bit 0:   Valid flag (always 1)
```

**Byte 2: Scan Code**
```
8-bit PS/2 scan code
```

### 5. View in Terminal

Binary data appears in terminal. To decode:

**Python decoder script**:
```python
#!/usr/bin/env python3
import serial

ser = serial.Serial('/dev/ttyUSB0', 115200)

while True:
    status = ser.read(1)[0]
    scancode = ser.read(1)[0]

    fifo_full = (status >> 3) & 1
    not_data_ready = (status >> 2) & 1
    interrupt = (status >> 1) & 1
    valid = status & 1

    print(f"Scan: 0x{scancode:02X} ({scancode:3d})", end="")

    if scancode == 0xF0:
        print(" <-- BREAK (key release)")
    elif scancode == 0xE0:
        print(" <-- EXTENDED")
    elif scancode == 0xAA:
        print(" <-- BAT OK")
    else:
        print()

    if fifo_full:
        print("  WARNING: FIFO FULL!")
```

Save as `decode_ps2.py` and run:
```bash
chmod +x decode_ps2.py
./decode_ps2.py
```

---

## Expected Results

### Keyboard Power-On

When keyboard powers up, it sends self-test code:
```
Scan: 0xAA (170) <-- BAT OK
```

### Single Key Press (letter 'A')

```
Scan: 0x1C (28)        # Make code
Scan: 0xF0 (240) <-- BREAK
Scan: 0x1C (28)        # Break code
```

### Extended Key (Up Arrow)

```
Scan: 0xE0 (224) <-- EXTENDED
Scan: 0x75 (117)       # Make code
Scan: 0xE0 (224) <-- EXTENDED
Scan: 0xF0 (240) <-- BREAK
Scan: 0x75 (117)       # Break code
```

---

## Troubleshooting

### No LEDs Light Up

**Check**:
1. FPGA programmed successfully?
2. Power connected?
3. Press RESET button
4. Check LED connections in LPF file

**Try**: Re-program with `make prog_fast`

### No Scan Codes in Terminal

**Check**:
1. UART TX connected to serial adapter RX?
2. GND connected between FPGA and serial adapter?
3. Correct serial port? (`ls /dev/ttyUSB*`)
4. Correct baud rate? (115200)

**Try**:
```bash
# Test with loopback
screen /dev/ttyUSB0 115200
# Type some characters - do they echo?
```

### Scan Codes but D1 (data_ready) Never Lights

**Cause**: PS/2 decoder reading data but LED logic might be inverted

**Fix**: This is cosmetic - UART output is what matters

### D3 (FIFO full) Lights Up

**Cause**: UART not transmitting fast enough, scan codes backing up

**Check**:
1. UART TX connected?
2. Baud rate correct (CLKS_PER_BIT = 217 for 25MHz/115200)?

### Wrong Scan Codes

**Check**:
1. PS/2 clock and data swapped? (Swap K5 and B3)
2. Bad connections (intermittent)?
3. Power supply noisy?

**Try**:
- Add external pull-up resistors (4.7K to 3.3V) on clock and data lines
- Use level shifter if keyboard is 5V

### Build Errors

**"Cannot find module"**:
```bash
# Check library path
ls ../../wrappers/fpga/ps2_femtorv_wrapper.v

# Should exist. If not:
cd /opt/wip/ps2-controller-lib
ls -la wrappers/fpga/
```

**Yosys errors**:
```bash
# Try manual synthesis to see detailed errors
yosys -p "read_verilog -I../.. ps2_test_top.v; synth_ecp5 -top ps2_test_top"
```

---

## Comparison: Standalone vs Full SoC

| Feature | Standalone Test (this) | FemtoRV SoC Test |
|---------|------------------------|------------------|
| **CPU** | None | RISC-V RV32I |
| **RAM** | None | 8 KB |
| **Firmware** | None (pure hardware) | C program |
| **Build Time** | 30 sec | 2-3 min |
| **LUTs** | ~200 | ~2800 |
| **Complexity** | Low | High |
| **Purpose** | Verify PS/2 hardware | Full system test |
| **Debug** | Easy (LEDs + UART) | Harder (CPU involved) |

---

## Next Steps

### If This Test Works ✅

1. **Verify scan codes are correct** - compare to PS/2 scan code tables
2. **Test different keyboards** - verify compatibility
3. **Check timing** - should handle fast typing without FIFO overflow
4. **Move to FemtoRV integration** - now you know PS/2 hardware works!

### If This Test Fails ❌

**Don't proceed to FemtoRV yet!** Debug here first:
1. Use logic analyzer on PS/2 clock/data lines
2. Check waveforms (clock should be ~10-16 kHz)
3. Verify power supply stability
4. Try different keyboard
5. Check for shorts/bad connections

---

## Files in This Directory

- **ps2_test_top.v** - Top-level test module
- **uart_tx_simple.v** - Simple UART transmitter
- **colorlight_i5.lpf** - Pin constraints for Colorlight i5
- **Makefile** - Build automation
- **README.md** - This file

## References

- PS/2 Protocol: https://wiki.osdev.org/PS/2_Keyboard
- Colorlight i5: https://github.com/wuxx/Colorlight-FPGA-Projects
- Library Source: `../../rtl/` and `../../wrappers/fpga/`

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│         ps2_test_top (No CPU!)                  │
│                                                 │
│  ┌──────────────┐      ┌─────────────────┐    │
│  │ PS/2 Keyboard│──────▶│ ps2_decoder     │    │
│  │ (External)   │       │ _device         │    │
│  └──────────────┘       │ (Wrapper)       │    │
│                         │  ├─ decoder_core│    │
│   ps2_clk ──────────────▶  ├─ debounce    │    │
│   ps2_data ─────────────▶  └─ dual_fifo   │    │
│                         └────────┬──────────    │
│                                  │              │
│                         ┌────────▼──────────┐   │
│                         │ State Machine     │   │
│                         │ (reads FIFO,      │   │
│                         │  sends to UART)   │   │
│                         └────────┬──────────┘   │
│                                  │              │
│                         ┌────────▼──────────┐   │
│                         │ uart_tx_simple    │   │
│                         └────────┬──────────┘   │
│                                  │              │
│   uart_tx ◀─────────────────────┘              │
│                                                 │
│   LEDs (status) ◀───────────────────────────── │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Key Point**: This is pure hardware. Scan codes flow directly from PS/2 decoder to UART TX. No CPU, no firmware, no software - just Verilog.

---

**Ready to test? Run `make` and `make prog_fast`!** 🚀
