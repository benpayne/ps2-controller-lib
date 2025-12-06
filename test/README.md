# PS/2 Controller Library Tests

This directory contains tests for the PS/2 controller library.

## Test Organization

### Core Module Tests (✅ Recommended)

**Location:** `test/test_core.py`  
**Run:** `make`  
**Status:** ✅ All 9 tests pass

These tests validate the core `ps2_decoder_core` module without debouncing, providing fast and reliable validation of the PS/2 protocol implementation.

**Coverage:**
- Single byte reception
- Multiple byte sequences
- Parity error detection
- Stop bit error detection
- Interrupt handling
- Edge cases (0x00, 0xFF)
- Reset during transmission
- Back-to-back bytes

**Why these are reliable:** No debouncing delays, direct control of PS/2 signals, fast simulation.

### Wrapper UART Tests (✅ Recommended)

**Location:** `test/test_wrapper_uart.py`  
**Run:** `make -f Makefile.uart`  
**Status:** ✅ All 6 tests pass

These tests validate the wrapper's UART state machine and ASCII encoding logic by directly injecting data into the FIFO, bypassing PS/2 protocol and debouncing.

**Coverage:**
- ASCII hex encoding (`hex_to_ascii` function)
- UART state machine transitions
- Multiple scancode transmission
- All hex values (0x00-0xFF)
- FIFO management and timing
- UART busy signal behavior
- Rapid data injection

**Why these work well:** Bypasses debouncing and PS/2 timing complexity to focus on wrapper-specific logic.

### FemtoRV Wrapper Tests (✅ Integration Coverage)

**Location:** `test/test_ps2_femtorv_wrapper.py`  
**Run:** `make -f Makefile.femtorv`  
**Status:** ✅ All 4 tests pass

These tests drive real PS/2 waveforms (using the shared driver) into the FemtoRV memory-mapped wrapper and perform CPU-style reads to verify the full integration path.

**Coverage:**
- Single-byte reads and status bits
- FIFO queueing of multiple scan codes
- Interrupt pulse behavior
- Extended (E0) and break (F0) sequences

**Why these matter:** Exercises the same wrapper that runs inside FemtoRV/FemtoRV-like SoCs without needing the whole CPU build.

### FPGA Hardware Tests (✅ Primary Hardware Validation)

**Location:** `test/fpga/`  
**Run:** `cd test/fpga && make`  
**Status:** ✅ Bitstream builds successfully

The FPGA test builds a complete system with:
- PS/2 keyboard input
- UART output (ASCII hex)
- 7-segment display
- LED indicators

**This is the primary validation** for real hardware, as it tests with:
- Real PS/2 timing
- Actual debouncing behavior
- Hardware synthesis constraints

## Running Tests

### Quick Test (Recommended)

```bash
cd test/

# Core PS/2 protocol tests
make                          # ✅ 9/9 tests pass

# Wrapper UART logic tests  
make -f Makefile.uart         # ✅ 6/6 tests pass

# FemtoRV wrapper integration tests
make -f Makefile.femtorv      # ✅ 4/4 tests pass

# Total: 19/19 tests pass
```

### FPGA Build

```bash
cd test/fpga/

# Build bitstream
make                          # ✅ Synthesis succeeds

# Program FPGA
make prog                     # Flash to FPGA

# Monitor output
./monitor_ps2.sh              # View UART output
```

## Test Summary

| Test Suite | Command | Tests | Status | Purpose |
|------------|---------|-------|--------|---------|
| Core | `make` | 9/9 | ✅ PASS | PS/2 protocol logic |
| Wrapper | `make -f Makefile.uart` | 6/6 | ✅ PASS | UART state machine |
| FemtoRV Wrapper | `make -f Makefile.femtorv` | 4/4 | ✅ PASS | Memory-mapped wrapper |
| FPGA Build | `cd fpga && make` | N/A | ✅ PASS | Hardware synthesis |

**Total: 19/19 tests pass**

## Test Infrastructure

### Common Test Code

**Location:** `test/common/ps2_sim_driver.py`

Reusable PS/2 simulation infrastructure:
- `PS2Driver` - Simulates PS/2 protocol with proper timing
- `ScanCodeSet1`, `ScanCodeSet2` - Standard scan codes
- Helper methods for make/break codes, extended keys, error injection

**Example:**
```python
from common.ps2_sim_driver import PS2Driver, ScanCodeSet2

ps2 = PS2Driver(dut)
await ps2.idle()
await ps2.send_scancode(ScanCodeSet2.A)  # Send 'A' key
```

## Test Requirements

Install dependencies:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Required packages:**
- `cocotb>=1.8.0` - Python co-simulation framework
- `pytest>=7.0.0` - Test framework (used by cocotb)

**Required tools:**
- Icarus Verilog (`iverilog`) - Verilog simulator
- Yosys (for FPGA builds) - Synthesis
- nextpnr-ecp5 (for FPGA builds) - Place & route
- ecppack (for FPGA builds) - Bitstream generation

## Debugging Failed Tests

### View Waveforms

Tests generate VCD waveform files:
```bash
cd test/
make
gtkwave tb_core.vcd &
```

### Increase Simulation Time

For wrapper tests with timing issues, increase wait times in test file:

```python
# Before
await Timer(200, units='us')

# After
await Timer(2000, units='us')  # 10x longer
```

### Reduce Debounce for Simulation

Edit wrapper to use shorter debounce (for testing only):

```verilog
debounce #(
    .DEBOUNCE_CYCLES(4)  // Reduced from 128 for simulation
) ps2_clk_debounce (
    // ...
);
```

## Recommendations

**For development:**
1. Run core tests frequently (`make`)
2. Run wrapper-specific tests as needed (`make -f Makefile.uart`, `make -f Makefile.femtorv`)
3. Test FPGA builds before commits

**For validation:**
1. ✅ Core tests must pass (9/9)
2. ✅ Wrapper suites should pass when wrapper logic changes (6/6 + 4/4)
3. ✅ FPGA build must succeed

**For hardware:**
1. Program FPGA: `cd test/fpga && make prog`
2. Monitor UART: `./monitor_ps2.sh`
3. Verify scan codes on 7-segment display

## Known Issues

1. **Simulation runtime** - FemtoRV tests run real PS/2 timings (≈10 kHz), so they are slower than the UART-only suite.
2. **Cocotb deprecation warnings** - `units` vs `unit` parameter naming (cosmetic, doesn't affect tests)
3. **FST warnings** - Multiple $dumpfile calls (cosmetic, doesn't affect tests)

## License

Apache-2.0

## Author

Ben Payne, 2024

