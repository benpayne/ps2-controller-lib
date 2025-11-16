# PS/2 Controller Library

Reusable, well-tested PS/2 keyboard decoder modules for FPGA and ASIC designs.

## Features

- **Parameterized clock frequency** - Works with any system clock
- **Metastability protection** - 2-FF synchronizer on async inputs
- **Comprehensive testing** - 95%+ code coverage with 16+ tests
- **ASIC-proven** - Taped out on GF180MCU (TinyTapeout)
- **FPGA-proven** - Tested on Colorlight i5 (ECP5)

## Modules

### Core Library (`rtl/`)

These are the reusable, portable core modules:

- **`ps2_decoder_core.v`** - PS/2 protocol decoder with validation
- **`debounce.v`** - Input debouncer with 2-FF synchronizer
- **`dual_fifo.v`** - Simple dual-port synchronous FIFO

### Wrappers (`wrappers/`)

Project-specific wrappers that use the core modules:

- **`wrappers/fpga/ps2_femtorv_wrapper.v`** - FemtoRV memory-mapped I/O interface
- **`wrappers/asic/ps2_gf180_wrapper.v`** - GF180 ASIC with VPWR/VGND rails

## Usage

### As Git Submodule

```bash
# In your project directory
git submodule add https://github.com/YOUR_USERNAME/ps2-controller-lib.git lib/ps2-controller-lib
git submodule update --init --recursive
```

### In Your Makefile

Add the library path to your include search:

```makefile
# Yosys
VERILOG_INCLUDES = -I$(PROJECT_ROOT)/lib/ps2-controller-lib

# Icarus Verilog
IVERILOG_FLAGS = -I $(PROJECT_ROOT)/lib/ps2-controller-lib

# Verilator
VERILATOR_FLAGS = -y $(PROJECT_ROOT)/lib/ps2-controller-lib/rtl
```

### In Your Verilog

```verilog
// Include the wrapper (which includes the core modules)
`include "wrappers/fpga/ps2_femtorv_wrapper.v"

// Instantiate
ps2_decoder_device #(
    .CLK_FREQ_HZ(50_000_000)  // 50 MHz system clock
) ps2_kbd (
    .reset(reset_n),
    .clk(clk),
    .rstrb(mem_rstrb),
    .rdata(ps2_rdata),
    .sel(ps2_sel),
    .interrupt(ps2_interrupt),
    .data_ready(ps2_data_ready),
    .ps2_clk(ps2_clk_pin),
    .ps2_data(ps2_data_pin)
);
```

## Testing

The library includes comprehensive cocotb tests:

```bash
cd test
make
```

Tests cover:
- Basic protocol (single/multiple bytes)
- Error handling (parity, start/stop bit errors)
- FIFO overflow
- Edge cases (0x00, 0xFF, variable clock speeds)
- Reset during transmission

## Parameters

### `ps2_decoder_core`

- `CLK_FREQ_HZ` - System clock frequency in Hz (default: 25 MHz)
- `PS2_CLK_HZ` - PS/2 clock frequency in Hz (default: 10 kHz)

### `debounce`

- `DEBOUNCE_CYCLES` - Number of stable clock cycles required (default: 128)

### `dual_fifo`

- `DEPTH` - FIFO depth as 2^DEPTH entries (default: 2 → 4 entries)
- `WIDTH` - Data bus width in bits (default: 8)

## Projects Using This Library

- [learn-fpga](https://github.com/BrunoLevy/learn-fpga) - FemtoRV retro co-processor
- [ttgf-ps2-m68k](https://github.com/YOUR_USERNAME/ttgf-ps2-m68k) - TinyTapeout GF180 PS/2 decoder

## License

Apache-2.0

## Author

Ben Payne, 2024
