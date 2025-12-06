"""
FemtoRV PS/2 wrapper tests.

These tests exercise the memory-mapped wrapper by driving PS/2 waveforms
via the shared simulation driver and issuing CPU-style reads on the
`sel`/`rstrb` interface. They verify that:
  - bytes propagate from the PS/2 pins into the wrapper's read buffer
  - status bits reflect FIFO state
  - `data_ready` and `interrupt` behave as documented
  - extended (E0) and break (F0) sequences are preserved
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from common.ps2_sim_driver import PS2Driver, ScanCodeSet2

CLK_PERIOD_NS = 20  # 50 MHz system clock


async def reset_dut(dut):
    """Apply an active-low reset and drive control signals to a known state."""
    dut.reset_n.value = 0
    dut.sel.value = 0
    dut.rstrb.value = 0
    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    await Timer(200, unit="ns")
    dut.reset_n.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def wait_for_data_ready(dut, timeout_ns=5_000_000):
    """Wait until the read buffer signals that a byte is available."""
    elapsed = 0
    while elapsed < timeout_ns:
        if int(dut.data_ready.value) == 1:
            return
        await RisingEdge(dut.clk)
        elapsed += CLK_PERIOD_NS
    core_valid = int(dut.dut.ps2_core.valid.value)
    core_state = int(dut.dut.ps2_core.state_reg.value)
    shift_reg = int(dut.dut.ps2_core.shift_reg.value)
    clk_timeout = int(dut.dut.ps2_core.clk_timeout.value)
    debounced_clk = int(dut.dut.ps2_clk_debounce.debounced_button.value)
    dut._log.error(
        "Timeout waiting for data_ready: ps2_clk=%s debounced_clk=%d ps2_data=%s core_valid=%d core_state=%d clk_timeout=%d shift_reg=0x%03X",
        dut.ps2_clk.value,
        debounced_clk,
        dut.ps2_data.value,
        core_valid,
        core_state,
        clk_timeout,
        shift_reg,
    )
    raise AssertionError("Timed out waiting for data_ready to assert")


async def cpu_read(dut):
    """Perform a single FemtoRV bus read (sel & rstrb high for one cycle)."""
    dut.sel.value = 1
    dut.rstrb.value = 1
    await Timer(CLK_PERIOD_NS // 2, unit="ns")
    read_value = int(dut.rdata.value)
    await RisingEdge(dut.clk)
    dut.sel.value = 0
    dut.rstrb.value = 0
    await RisingEdge(dut.clk)
    return read_value


def decode_status(word):
    """Extract status flags and the data byte from a wrapper read."""
    status = (word >> 8) & 0x3
    fifo_full = (status >> 1) & 0x1
    fifo_empty = status & 0x1
    data_byte = word & 0xFF
    return fifo_full, fifo_empty, data_byte


def configure_ps2_driver(dut):
    """Create a PS/2 driver that uses the default (~10 kHz) timing."""
    return PS2Driver(dut)


async def wait_interrupt_pulse(dut):
    """Wait for the interrupt line to pulse high."""
    await RisingEdge(dut.interrupt)


@cocotb.test()
async def test_single_scancode_read(dut):
    """Send one scan code and verify the CPU can read it back."""
    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    driver = configure_ps2_driver(dut)

    await reset_dut(dut)

    await driver.send_scancode(ScanCodeSet2.A)
    await wait_for_data_ready(dut)

    read_word = await cpu_read(dut)
    fifo_full, fifo_empty, data_byte = decode_status(read_word)

    assert data_byte == ScanCodeSet2.A, f"Expected 0x1C, got 0x{data_byte:02X}"
    assert fifo_full == 0, "FIFO should not be full for a single byte"
    assert fifo_empty == 1, "FIFO should be empty after consuming the byte"

    await RisingEdge(dut.clk)
    assert int(dut.data_ready.value) == 0, "data_ready did not clear after read"


@cocotb.test()
async def test_multiple_scancodes_queue(dut):
    """Verify that multiple bytes can be queued and read in order."""
    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    driver = configure_ps2_driver(dut)
    await reset_dut(dut)

    sequence = [ScanCodeSet2.A, ScanCodeSet2.S, ScanCodeSet2.D]
    for code in sequence:
        await driver.send_scancode(code)
        await Timer(50, unit="us")

    received = []
    for expected in sequence:
        await wait_for_data_ready(dut)
        word = await cpu_read(dut)
        _, _, data_byte = decode_status(word)
        received.append(data_byte)
        await RisingEdge(dut.clk)

    assert received == sequence, f"Out-of-order data: {received} vs {sequence}"


@cocotb.test()
async def test_interrupt_pulse(dut):
    """Interrupt should pulse each time a new byte hits the read buffer."""
    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    driver = configure_ps2_driver(dut)
    await reset_dut(dut)

    interrupt_task = cocotb.start_soon(wait_interrupt_pulse(dut))

    await driver.send_scancode(ScanCodeSet2.F)
    await wait_for_data_ready(dut)

    await interrupt_task

    _ = await cpu_read(dut)
    await RisingEdge(dut.clk)

    assert int(dut.interrupt.value) == 0, "Interrupt should be a pulse, not sticky"


@cocotb.test()
async def test_extended_break_sequence(dut):
    """Extended keys (E0 prefix) and break codes must propagate intact."""
    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    driver = configure_ps2_driver(dut)
    await reset_dut(dut)

    cocotb.start_soon(
        driver.send_key_press_release(ScanCodeSet2.RIGHT_ARROW, is_extended=True)
    )

    expected_bytes = [0xE0, ScanCodeSet2.RIGHT_ARROW, 0xE0, 0xF0, ScanCodeSet2.RIGHT_ARROW]
    received = []

    for _ in expected_bytes:
        await wait_for_data_ready(dut, timeout_ns=20_000_000)
        word = await cpu_read(dut)
        _, _, data_byte = decode_status(word)
        received.append(data_byte)
        await RisingEdge(dut.clk)

    assert received == expected_bytes, f"Extended sequence mismatch: {received}"

