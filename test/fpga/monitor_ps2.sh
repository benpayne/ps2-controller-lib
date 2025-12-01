#!/bin/bash
# PS/2 UART Monitor - Works with ASCII hex format
# For use with ps2_direct_with_display.v

PORT=${1:-/dev/ttyACM0}

echo "========================================="
echo "PS/2 Scan Code Monitor"
echo "========================================="
echo "Port: $PORT"
echo "Baud: 115200"
echo "Format: ASCII hex (e.g., 1C = scan code 0x1C)"
echo "Press Ctrl-C to exit"
echo "========================================="
echo ""

# Check if port exists
if [ ! -e "$PORT" ]; then
    echo "ERROR: Port $PORT not found!"
    echo ""
    echo "Available serial ports:"
    ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null || echo "  (none found)"
    echo ""
    exit 1
fi

# Configure port
stty -F $PORT 115200 raw -echo

# Read and display with some formatting
echo "Waiting for scan codes... (press keys on PS/2 keyboard)"
echo ""

cat $PORT

