# Makefile for ps2-controller-lib core module tests
# Tests the core modules directly without wrapper complexity

# Simulator
SIM ?= icarus
WAVES ?= 1
TOPLEVEL_LANG ?= verilog

# Core library sources (use absolute paths to avoid cocotb Makefile issues)
VERILOG_SOURCES = $(shell pwd)/../rtl/ps2_decoder_core.v
VERILOG_SOURCES += $(shell pwd)/../rtl/debounce.v
VERILOG_SOURCES += $(shell pwd)/../rtl/dual_fifo.v

# Testbench
VERILOG_SOURCES += $(shell pwd)/tb_core.v
TOPLEVEL = tb_core

# Python test module
MODULE = test_core

# No extra compile args needed with absolute paths
# COMPILE_ARGS +=

# Cocotb
include $(shell cocotb-config --makefiles)/Makefile.sim

# Helper targets
.PHONY: clean_all view

clean_all: clean
	rm -rf sim_build __pycache__ results.xml *.vcd *.log

view: tb_core.vcd
	gtkwave $< &
