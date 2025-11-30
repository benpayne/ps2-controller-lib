#!/bin/bash
# General-purpose UART monitor for FPGA tests
# Works with any UART test module

PORT=${1:-/dev/ttyACM0}

echo "========================================="
echo "UART Monitor"
echo "========================================="
echo "Port: $PORT"
echo "Baud: 115200"
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

# Configure port and display hex dump
stty -F $PORT 115200 raw -echo
cat $PORT | xxd

