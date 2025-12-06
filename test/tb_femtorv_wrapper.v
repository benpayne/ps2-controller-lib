`default_nettype none
`timescale 1ns/1ps

// Simple top-level testbench wrapper that exposes the FemtoRV PS/2 device
// ports directly to cocotb. The actual stimulus is provided from Python.
module tb_femtorv_wrapper (
    input  wire        clk,
    input  wire        reset_n,   // Active-low reset to match FemtoRV convention
    input  wire        rstrb,
    input  wire        sel,
    output wire [31:0] rdata,
    output wire        interrupt,
    output wire        data_ready,
    input  wire        ps2_clk,
    input  wire        ps2_data
);

    // Instantiate the actual wrapper under test
    ps2_decoder_device #(
        .CLK_FREQ_HZ(50_000_000)
    ) dut (
        .reset(reset_n),
        .clk(clk),
        .rstrb(rstrb),
        .rdata(rdata),
        .sel(sel),
        .interrupt(interrupt),
        .data_ready(data_ready),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data)
    );

    // Waveform dumping for debugging
    initial begin
        $dumpfile("tb_femtorv_wrapper.vcd");
        $dumpvars(0, tb_femtorv_wrapper);
    end

endmodule

`default_nettype wire

