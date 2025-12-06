"""
PS/2 Simulation Driver

Common utilities for simulating PS/2 keyboard behavior in Cocotb tests.
This provides reusable functions to:
- Send PS/2 scan codes with proper timing
- Generate make/break codes
- Handle extended scan codes
- Simulate various PS/2 protocol scenarios

Author: Ben Payne, 2024
License: Apache-2.0
"""

import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock


class PS2Driver:
    """Driver for simulating PS/2 keyboard protocol."""
    
    def __init__(self, dut, clk_signal="clk", ps2_clk_signal="ps2_clk", ps2_data_signal="ps2_data"):
        """
        Initialize PS/2 driver.
        
        Args:
            dut: Device under test
            clk_signal: Name of system clock signal (default: "clk")
            ps2_clk_signal: Name of PS/2 clock signal (default: "ps2_clk")
            ps2_data_signal: Name of PS/2 data signal (default: "ps2_data")
        """
        self.dut = dut
        self.clk = getattr(dut, clk_signal)
        self.ps2_clk = getattr(dut, ps2_clk_signal)
        self.ps2_data = getattr(dut, ps2_data_signal)
        
        # PS/2 timing defaults (can be overridden)
        self.ps2_clk_period_us = 100  # 100us = 10kHz (typical PS/2 clock)
        self.post_byte_idle_us = 150  # Time to remain idle after a byte (us)
        
    async def idle(self):
        """Set PS/2 signals to idle state (both high)."""
        self.ps2_clk.value = 1
        self.ps2_data.value = 1
        
    async def send_byte(self, byte_value):
        """
        Send a single byte over PS/2 protocol.
        
        Args:
            byte_value: 8-bit value to send
            
        Returns:
            True if successful, False if error
        """
        # Start bit (always 0)
        await self._send_bit(0)
        
        # Data bits (LSB first)
        parity = 0
        for i in range(8):
            bit = (byte_value >> i) & 1
            await self._send_bit(bit)
            parity ^= bit
        
        # Parity bit (odd parity)
        await self._send_bit(parity ^ 1)
        
        # Stop bit (always 1)
        await self._send_bit(1)
        
        # Return to idle
        await self.idle()
        await Timer(self.post_byte_idle_us, unit='us')
        
        return True
        
    async def _send_bit(self, bit_value):
        """
        Send a single bit with PS/2 clock.
        
        Args:
            bit_value: 0 or 1
        """
        # Data is set before clock falls
        self.ps2_data.value = bit_value
        await Timer(self.ps2_clk_period_us // 4, unit='us')
        
        # Clock falls
        self.ps2_clk.value = 0
        await Timer(self.ps2_clk_period_us // 2, unit='us')
        
        # Clock rises (data is sampled on rising edge)
        self.ps2_clk.value = 1
        await Timer(self.ps2_clk_period_us // 4, unit='us')
        
    async def send_scancode(self, scancode, is_extended=False, is_break=False):
        """
        Send a complete scan code (with optional extended and break prefixes).
        
        Args:
            scancode: Base scan code byte
            is_extended: If True, send E0 prefix (default: False)
            is_break: If True, send F0 prefix (default: False)
            
        Example:
            # Send 'A' key press (Set 2)
            await driver.send_scancode(0x1C, is_extended=False, is_break=False)
            
            # Send 'A' key release (Set 2)
            await driver.send_scancode(0x1C, is_extended=False, is_break=True)
            
            # Send Right Arrow key press (Set 2, extended)
            await driver.send_scancode(0x74, is_extended=True, is_break=False)
        """
        if is_extended:
            await self.send_byte(0xE0)
            
        if is_break:
            await self.send_byte(0xF0)
            
        await self.send_byte(scancode)
        
    async def send_key_press_release(self, scancode, is_extended=False, delay_us=1000):
        """
        Send a complete key press and release sequence.
        
        Args:
            scancode: Base scan code byte
            is_extended: If True, send extended scan codes
            delay_us: Delay between press and release in microseconds
        """
        # Make code (key press)
        await self.send_scancode(scancode, is_extended=is_extended, is_break=False)
        
        # Delay between press and release
        await Timer(delay_us, unit='us')
        
        # Break code (key release)
        await self.send_scancode(scancode, is_extended=is_extended, is_break=True)
        
    async def send_invalid_parity(self, byte_value):
        """
        Send a byte with intentionally wrong parity (for error testing).
        
        Args:
            byte_value: 8-bit value to send
        """
        # Start bit
        await self._send_bit(0)
        
        # Data bits
        parity = 0
        for i in range(8):
            bit = (byte_value >> i) & 1
            await self._send_bit(bit)
            parity ^= bit
        
        # Wrong parity bit (even instead of odd)
        await self._send_bit(parity)  # Should be parity ^ 1
        
        # Stop bit
        await self._send_bit(1)
        
        # Return to idle
        await self.idle()
        await Timer(self.post_byte_idle_us, unit='us')
        
    async def send_invalid_stop_bit(self, byte_value):
        """
        Send a byte with invalid stop bit (for error testing).
        
        Args:
            byte_value: 8-bit value to send
        """
        # Start bit
        await self._send_bit(0)
        
        # Data bits
        parity = 0
        for i in range(8):
            bit = (byte_value >> i) & 1
            await self._send_bit(bit)
            parity ^= bit
        
        # Parity bit (correct)
        await self._send_bit(parity ^ 1)
        
        # Wrong stop bit (0 instead of 1)
        await self._send_bit(0)
        
        # Return to idle
        await self.idle()
        await Timer(self.post_byte_idle_us, unit='us')


# Common scan code sets for testing
class ScanCodeSet2:
    """PS/2 Scan Code Set 2 (most common)."""
    
    # Letters
    A = 0x1C
    B = 0x32
    C = 0x21
    D = 0x23
    E = 0x24
    F = 0x2B
    G = 0x34
    H = 0x33
    I = 0x43
    J = 0x3B
    K = 0x42
    L = 0x4B
    M = 0x3A
    N = 0x31
    O = 0x44
    P = 0x4D
    Q = 0x15
    R = 0x2D
    S = 0x1B
    T = 0x2C
    U = 0x3C
    V = 0x2A
    W = 0x1D
    X = 0x22
    Y = 0x35
    Z = 0x1A
    
    # Numbers
    NUM_0 = 0x45
    NUM_1 = 0x16
    NUM_2 = 0x1E
    NUM_3 = 0x26
    NUM_4 = 0x25
    NUM_5 = 0x2E
    NUM_6 = 0x36
    NUM_7 = 0x3D
    NUM_8 = 0x3E
    NUM_9 = 0x46
    
    # Function keys
    F1 = 0x05
    F2 = 0x06
    F3 = 0x04
    F4 = 0x0C
    F5 = 0x03
    F6 = 0x0B
    F7 = 0x83
    F8 = 0x0A
    F9 = 0x01
    F10 = 0x09
    F11 = 0x78
    F12 = 0x07
    
    # Special keys
    ENTER = 0x5A
    SPACE = 0x29
    BACKSPACE = 0x66
    TAB = 0x0D
    ESC = 0x76
    CAPS_LOCK = 0x58
    LEFT_SHIFT = 0x12
    RIGHT_SHIFT = 0x59
    LEFT_CTRL = 0x14
    LEFT_ALT = 0x11
    
    # Extended keys (require 0xE0 prefix)
    RIGHT_CTRL = 0x14  # E0 14
    RIGHT_ALT = 0x11   # E0 11
    LEFT_ARROW = 0x6B  # E0 6B
    RIGHT_ARROW = 0x74 # E0 74
    UP_ARROW = 0x75    # E0 75
    DOWN_ARROW = 0x72  # E0 72
    HOME = 0x6C        # E0 6C
    END = 0x69         # E0 69
    PAGE_UP = 0x7D     # E0 7D
    PAGE_DOWN = 0x7A   # E0 7A
    INSERT = 0x70      # E0 70
    DELETE = 0x71      # E0 71
    
    # Special sequences
    PREFIX_EXTENDED = 0xE0
    PREFIX_BREAK = 0xF0


class ScanCodeSet1:
    """PS/2 Scan Code Set 1 (older, used by some systems)."""
    
    # Letters (make codes)
    A = 0x1E
    B = 0x30
    C = 0x2E
    D = 0x20
    S = 0x1F
    
    # Break codes have bit 7 set
    @staticmethod
    def make_to_break(make_code):
        """Convert make code to break code (Set 1)."""
        return make_code | 0x80

