#!/usr/bin/env python3
"""
PS/2 Scan Code Decoder for Standalone Hardware Test

Reads 2-byte packets from UART:
  Byte 1: Status byte
  Byte 2: PS/2 scan code

Displays scan codes with interpretation.
"""

import sys
import argparse

try:
    import serial
    import serial.tools.list_ports
    HAS_SERIAL = True
except ImportError:
    HAS_SERIAL = False
    print("ERROR: pyserial not installed")
    print("Install with: pip3 install pyserial")
    print("Or: sudo apt-get install python3-serial")
    sys.exit(1)

# PS/2 Scan Code Set 2 - Common codes
SCAN_CODES = {
    0x1C: 'A', 0x32: 'B', 0x21: 'C', 0x23: 'D', 0x24: 'E',
    0x2B: 'F', 0x34: 'G', 0x33: 'H', 0x43: 'I', 0x3B: 'J',
    0x42: 'K', 0x4B: 'L', 0x3A: 'M', 0x31: 'N', 0x44: 'O',
    0x4D: 'P', 0x15: 'Q', 0x2D: 'R', 0x1B: 'S', 0x2C: 'T',
    0x3C: 'U', 0x2A: 'V', 0x1D: 'W', 0x22: 'X', 0x35: 'Y', 0x1A: 'Z',
    0x16: '1', 0x1E: '2', 0x26: '3', 0x25: '4', 0x2E: '5',
    0x36: '6', 0x3D: '7', 0x3E: '8', 0x46: '9', 0x45: '0',
    0x5A: 'Enter', 0x76: 'Esc', 0x66: 'Backspace', 0x0D: 'Tab',
    0x29: 'Space', 0x4E: '-', 0x55: '=', 0x54: '[', 0x5B: ']',
    0x5D: '\\', 0x4C: ';', 0x52: "'", 0x0E: '`',
    0x41: ',', 0x49: '.', 0x4A: '/',
    0x58: 'CapsLock', 0x05: 'F1', 0x06: 'F2', 0x04: 'F3', 0x0C: 'F4',
    0x03: 'F5', 0x0B: 'F6', 0x83: 'F7', 0x0A: 'F8', 0x01: 'F9',
    0x09: 'F10', 0x78: 'F11', 0x07: 'F12',
    0x12: 'LShift', 0x59: 'RShift', 0x14: 'LCtrl', 0x11: 'LAlt',
    0xF0: 'BREAK', 0xE0: 'EXTENDED',
    0xAA: 'BAT_OK', 0xFC: 'ERROR', 0xFD: 'ERROR', 0xFE: 'RESEND',
}

def decode_status(status):
    """Decode status byte into flags"""
    fifo_full = (status >> 3) & 1
    not_data_ready = (status >> 2) & 1
    interrupt = (status >> 1) & 1
    valid = status & 1
    return fifo_full, not_data_ready, interrupt, valid

def decode_scancode(scancode):
    """Get human-readable name for scan code"""
    return SCAN_CODES.get(scancode, '???')

def main():
    parser = argparse.ArgumentParser(description='PS/2 Scan Code Decoder')
    parser.add_argument('port', nargs='?', default='/dev/ttyUSB0',
                        help='Serial port (default: /dev/ttyUSB0)')
    parser.add_argument('-b', '--baud', type=int, default=115200,
                        help='Baud rate (default: 115200)')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Show status byte details')
    parser.add_argument('-d', '--debug', action='store_true',
                        help='Show raw hex bytes')
    args = parser.parse_args()

    try:
        ser = serial.Serial(args.port, args.baud, timeout=1)
        print(f"Connected to {args.port} at {args.baud} baud")
        print("Waiting for PS/2 scan codes...")
        print("=" * 60)
        print()

        count = 0

        while True:
            # Read 2-byte packet
            try:
                data = ser.read(2)
            except Exception as e:
                print(f"Error reading serial: {e}")
                continue

            if len(data) == 0:
                continue  # Timeout, keep waiting

            if len(data) != 2:
                print(f"Warning: Got {len(data)} bytes instead of 2, skipping")
                continue

            status = data[0]
            scancode = data[1]
            count += 1

            # Debug mode: show raw bytes
            if args.debug:
                print(f"[{count:4d}] Raw: {status:02X} {scancode:02X}")
                continue

            # Decode status
            fifo_full, not_ready, interrupt, valid = decode_status(status)

            # Print scan code
            name = decode_scancode(scancode)
            print(f"[{count:4d}] 0x{scancode:02X} ({scancode:3d}) = {name:12s}", end="")

            # Highlight special codes
            if scancode == 0xF0:
                print("  <-- Key Release Prefix", end="")
            elif scancode == 0xE0:
                print("  <-- Extended Key Prefix", end="")
            elif scancode == 0xAA:
                print("  <-- Power-On Self Test OK", end="")
            elif scancode in [0xFC, 0xFD]:
                print("  <-- ERROR!", end="")
            elif scancode == 0xFE:
                print("  <-- Resend Request", end="")

            # Show warnings
            if fifo_full:
                print("  [FIFO FULL!]", end="")

            # Verbose status
            if args.verbose:
                print(f"  |Status: 0x{status:02X} ", end="")
                print(f"[Full:{fifo_full} Int:{interrupt} Valid:{valid}]", end="")

            print()  # Newline

    except serial.SerialException as e:
        print(f"Error: {e}", file=sys.stderr)
        print(f"\nAvailable ports:", file=sys.stderr)
        if HAS_SERIAL:
            ports = serial.tools.list_ports.comports()
            for port in ports:
                print(f"  {port.device}: {port.description}", file=sys.stderr)
        sys.exit(1)

    except KeyboardInterrupt:
        print("\n\nExiting...")
        ser.close()
        sys.exit(0)

if __name__ == '__main__':
    main()
