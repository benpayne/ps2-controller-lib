# SPDX-FileCopyrightText: © 2024 Ben Payne
# SPDX-License-Identifier: Apache-2.0

"""
Test suite for ps2_decoder_core - the core PS/2 protocol decoder

This is a subset of the comprehensive ttgf-ps2-m68k tests,
adapted to test the core module directly without wrapper complexity.
"""

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock

# Helper functions for PS/2 protocol simulation

async def send_bit(ps2_clk, ps2_data, bit):
    """Send one bit on PS/2 bus"""
    ps2_data.value = bit
    ps2_clk.value = 1
    await Timer(50, units="us")
    ps2_clk.value = 0
    await Timer(50, units="us")


async def send_bits(ps2_clk, ps2_data, value, bit_count=8, parity_valid=True, stop_valid=True):
    """Send a complete PS/2 frame: start + data + parity + stop"""
    await send_bit(ps2_clk, ps2_data, 0)  # Start bit

    parity = 0
    for i in range(bit_count):
        bit = (value >> i) & 1
        parity ^= bit
        await send_bit(ps2_clk, ps2_data, bit)

    # Parity bit (odd parity)
    if parity_valid:
        await send_bit(ps2_clk, ps2_data, not parity)
    else:
        await send_bit(ps2_clk, ps2_data, parity)  # Wrong parity for testing

    # Stop bit
    if stop_valid:
        await send_bit(ps2_clk, ps2_data, 1)
    else:
        await send_bit(ps2_clk, ps2_data, 0)  # Wrong stop bit for testing

    ps2_clk.value = 1


# Basic Protocol Tests

@cocotb.test()
async def test_single_byte(dut):
    """Test decoding a single byte"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())  # 25 MHz

    dut.reset.value = 1
    dut.int_clear.value = 0
    await Timer(1, units="us")
    dut.reset.value = 0

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    await Timer(1, units="us")

    # Send byte 0xC2
    cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, 0xC2))

    # Wait for valid pulse
    await RisingEdge(dut.valid)

    # Check data
    await Timer(40, units="ns")  # One clock cycle
    assert dut.data.value == 0xC2, f"Expected 0xC2, got {dut.data.value:02x}"

    # Valid should clear after one cycle
    await Timer(40, units="ns")
    assert dut.valid.value == 0, "Valid should be cleared"

    # Interrupt should be set (takes one extra cycle after valid)
    assert dut.interrupt.value == 1, "Interrupt should be set"


@cocotb.test()
async def test_multiple_bytes(dut):
    """Test decoding multiple bytes in sequence"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    dut.reset.value = 1
    dut.int_clear.value = 0
    await Timer(1, units="us")
    dut.reset.value = 0

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    await Timer(1, units="us")

    test_bytes = [0xC2, 0xF0, 0xC2]  # Key down, break code, key up

    for test_byte in test_bytes:
        cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, test_byte))
        await RisingEdge(dut.valid)
        await Timer(40, units="ns")
        assert dut.data.value == test_byte, f"Expected {test_byte:02x}, got {dut.data.value:02x}"
        await Timer(100, units="us")  # Gap between bytes


@cocotb.test()
async def test_parity_error(dut):
    """Test that invalid parity is rejected"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    dut.reset.value = 1
    await Timer(1, units="us")
    dut.reset.value = 0

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    dut.int_clear.value = 0
    await Timer(1, units="us")

    # Send byte with wrong parity
    cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, 0xAA, parity_valid=False))

    # Wait sufficient time for frame to complete
    await Timer(2, units="ms")

    # Valid should NOT have pulsed
    assert dut.valid.value == 0, "Valid should not pulse for parity error"
    assert dut.interrupt.value == 0, "Interrupt should not be set for parity error"


@cocotb.test()
async def test_stop_bit_error(dut):
    """Test that invalid stop bit is rejected"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    dut.reset.value = 1
    await Timer(1, units="us")
    dut.reset.value = 0

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    dut.int_clear.value = 0
    await Timer(1, units="us")

    # Send byte with wrong stop bit
    cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, 0xAA, stop_valid=False))

    # Wait for frame
    await Timer(2, units="ms")

    # Valid should NOT have pulsed
    assert dut.valid.value == 0, "Valid should not pulse for stop bit error"


@cocotb.test()
async def test_interrupt_clear(dut):
    """Test that interrupt flag can be cleared"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    dut.reset.value = 1
    dut.int_clear.value = 0
    await Timer(1, units="us")
    dut.reset.value = 0

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    await Timer(1, units="us")

    # Send a byte
    cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, 0x1C))
    await RisingEdge(dut.valid)
    await Timer(80, units="ns")  # Wait 2 clock cycles for interrupt to register

    assert dut.interrupt.value == 1, "Interrupt should be set"

    # Clear interrupt
    dut.int_clear.value = 1
    await Timer(80, units="ns")  # 2 clock cycles
    dut.int_clear.value = 0

    await Timer(40, units="ns")
    assert dut.interrupt.value == 0, "Interrupt should be cleared"


@cocotb.test()
async def test_edge_cases_0x00(dut):
    """Test all-zeros byte"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    dut.reset.value = 1
    await Timer(1, units="us")
    dut.reset.value = 0

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    dut.int_clear.value = 0
    await Timer(1, units="us")

    # Send 0x00
    cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, 0x00))
    await RisingEdge(dut.valid)
    await Timer(40, units="ns")

    assert dut.data.value == 0x00, f"Expected 0x00, got {dut.data.value:02x}"


@cocotb.test()
async def test_edge_cases_0xFF(dut):
    """Test all-ones byte"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    dut.reset.value = 1
    await Timer(1, units="us")
    dut.reset.value = 0

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    dut.int_clear.value = 0
    await Timer(1, units="us")

    # Send 0xFF
    cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, 0xFF))
    await RisingEdge(dut.valid)
    await Timer(40, units="ns")

    assert dut.data.value == 0xFF, f"Expected 0xFF, got {dut.data.value:02x}"


@cocotb.test()
async def test_reset_during_transmission(dut):
    """Test that reset during byte transmission recovers correctly"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    dut.reset.value = 1
    await Timer(1, units="us")
    dut.reset.value = 0

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    dut.int_clear.value = 0
    await Timer(1, units="us")

    # Start sending a byte
    cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, 0xAB))

    # Reset mid-transmission (after ~5 bits)
    await Timer(500, units="us")
    dut.reset.value = 1
    await Timer(1, units="us")
    dut.reset.value = 0

    # Should recover and accept a new byte
    await Timer(2, units="ms")  # Let old transmission timeout

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    await Timer(100, units="us")

    cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, 0xCD))
    await RisingEdge(dut.valid)
    await Timer(40, units="ns")

    assert dut.data.value == 0xCD, f"Expected 0xCD after recovery, got {dut.data.value:02x}"


# Summary test
@cocotb.test()
async def test_back_to_back_bytes(dut):
    """Test rapid byte transmission with minimal gaps"""

    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    dut.reset.value = 1
    await Timer(1, units="us")
    dut.reset.value = 0

    dut.ps2_clk.value = 1
    dut.ps2_data.value = 1
    dut.int_clear.value = 0
    await Timer(1, units="us")

    test_sequence = [0x1C, 0x23, 0x2B, 0x34, 0x3B]  # "hello" scan codes

    for expected_byte in test_sequence:
        cocotb.start_soon(send_bits(dut.ps2_clk, dut.ps2_data, expected_byte))
        await RisingEdge(dut.valid)
        await Timer(40, units="ns")

        actual = dut.data.value
        assert actual == expected_byte, f"Expected {expected_byte:02x}, got {actual:02x}"

        # Minimal gap before next byte
        await Timer(150, units="us")
