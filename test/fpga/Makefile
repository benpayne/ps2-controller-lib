# Makefile for PS/2 Standalone Hardware Test (Colorlight i5)
#
# This builds a minimal test module (no CPU) to verify PS/2 hardware
# on the Colorlight i5 FPGA board.
#
# Usage:
#   make                  # Build bitstream
#   make prog             # Program FPGA (permanent flash)
#   make prog_fast        # Program FPGA (temporary RAM)
#   make clean            # Clean build files

PROJECTNAME = ps2_test
TOP_MODULE = uart_simple_test

# Source files
VERILOG_SOURCES = $(TOP_MODULE).v uart_tx.v

# Library paths (relative to this directory)
LIB_DIR = ../..
INCLUDE_PATHS = -I$(LIB_DIR)

# Yosys synthesis options
YOSYS_OPT = -q -p "read_verilog $(INCLUDE_PATHS) $(VERILOG_SOURCES); \
            synth_ecp5 -abc9 -top $(TOP_MODULE) -json $(PROJECTNAME).json"

# nextpnr place & route options
NEXTPNR_OPT = --force --timing-allow-fail --json $(PROJECTNAME).json \
              --lpf colorlight_i5.lpf --textcfg $(PROJECTNAME)_out.config \
              --25k --freq 25 --package CABGA381

# ecppack bitstream generation options
ECPPACK_OPT = --compress --svf-rowsize 100000 --svf $(PROJECTNAME).svf \
              $(PROJECTNAME)_out.config $(PROJECTNAME).bit

# Programming options
PROG_CMD = sudo openFPGALoader -c cmsisdap -v
PROG_FLASH_OPT = -f --unprotect-flash --file-type bin
PROG_FAST_OPT = --file-type bin

# Default target
all: $(PROJECTNAME).bit

# Synthesis with Yosys
$(PROJECTNAME).json: $(VERILOG_SOURCES)
	@echo "===================================="
	@echo "Synthesizing with Yosys..."
	@echo "===================================="
	yosys $(YOSYS_OPT)
	@echo "✓ Synthesis complete"

# Place & route with nextpnr
$(PROJECTNAME)_out.config: $(PROJECTNAME).json
	@echo "===================================="
	@echo "Place & Route with nextpnr-ecp5..."
	@echo "===================================="
	nextpnr-ecp5 $(NEXTPNR_OPT)
	@echo "✓ Place & route complete"

# Generate bitstream with ecppack
$(PROJECTNAME).bit: $(PROJECTNAME)_out.config
	@echo "===================================="
	@echo "Generating bitstream..."
	@echo "===================================="
	ecppack $(ECPPACK_OPT)
	@echo "✓ Bitstream generated: $(PROJECTNAME).bit"
	@ls -lh $(PROJECTNAME).bit

# Program FPGA (permanent flash)
prog: $(PROJECTNAME).bit
	@echo "===================================="
	@echo "Programming FPGA (flash)..."
	@echo "===================================="
	$(PROG_CMD) $(PROG_FLASH_OPT) $(PROJECTNAME).bit
	@echo "✓ FPGA programmed to flash"

# Program FPGA (temporary RAM - lost on power cycle)
prog_fast: $(PROJECTNAME).bit
	@echo "===================================="
	@echo "Programming FPGA (RAM)..."
	@echo "===================================="
	$(PROG_CMD) $(PROG_FAST_OPT) $(PROJECTNAME).bit
	@echo "✓ FPGA programmed to RAM"

# Show GUI
show: $(PROJECTNAME).json
	nextpnr-ecp5 $(NEXTPNR_OPT) --gui

# Lint check
lint:
	verilator --lint-only -top-module $(TOP_MODULE) \
	          $(INCLUDE_PATHS) $(VERILOG_SOURCES)

# Clean build artifacts
clean:
	rm -f *.json *.config *.bit *.svf *.rpt *~

# Display info
info:
	@echo "PS/2 Standalone Test for Colorlight i5"
	@echo "======================================="
	@echo "Top module: $(TOP_MODULE)"
	@echo "Sources:    $(VERILOG_SOURCES)"
	@echo "Library:    $(LIB_DIR)"
	@echo ""
	@echo "Targets:"
	@echo "  make          - Build bitstream"
	@echo "  make prog     - Program to flash (permanent)"
	@echo "  make prog_fast- Program to RAM (temporary)"
	@echo "  make lint     - Lint check with Verilator"
	@echo "  make clean    - Remove build files"

.PHONY: all prog prog_fast show lint clean info
