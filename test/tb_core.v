`default_nettype none
`timescale 1ns / 1ps

/* Testbench for ps2_decoder_core - tests the core module directly
   without any wrapper complexity */

module tb_core ();

  // Dump signals to VCD
  initial begin
    $dumpfile("tb_core.vcd");
    $dumpvars(0, tb_core);
    #1;
  end

  // Clock and reset
  reg clk;
  reg reset;

  // PS/2 interface (raw - debouncing tested separately)
  reg ps2_clk;
  reg ps2_data;

  // Control
  reg int_clear;

  // Outputs
  wire valid;
  wire interrupt;
  wire [7:0] data;

  // Instantiate the core decoder
  ps2_decoder_core #(
    .CLK_FREQ_HZ(25_000_000),  // 25 MHz like ttgf
    .PS2_CLK_HZ(10_000)        // 10 kHz PS/2 clock
  ) dut (
    .clk(clk),
    .reset(reset),
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),
    .int_clear(int_clear),
    .valid(valid),
    .interrupt(interrupt),
    .data(data)
  );

endmodule
