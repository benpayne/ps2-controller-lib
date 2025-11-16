// PS/2 Decoder Wrapper for FemtoRV
//
// This wrapper adapts the ps2_decoder_core to FemtoRV's memory-mapped I/O interface.
// It includes debouncing, FIFO buffering, and provides a simple register interface
// compatible with FemtoRV's bus protocol.
//
// Memory Map (when sel=1):
//   Read:  {22'b0, status[1:0], scancode[7:0]}
//          status[1] = FIFO full flag
//          status[0] = FIFO empty flag (inverted data_ready)
//
// Author: Ben Payne, 2024
// License: Apache-2.0

// Include the core library modules
// These paths are relative to the library root when included via -I flag or submodule
`include "rtl/ps2_decoder_core.v"
`include "rtl/debounce.v"
`include "rtl/dual_fifo.v"

module ps2_decoder_device #(
    parameter CLK_FREQ_HZ = 50_000_000  // FemtoRV typical clock frequency
)(
    input  wire        reset,      // Active-low reset (FemtoRV convention)
    input  wire        clk,        // System clock
    input  wire        rstrb,      // Read strobe
    output wire [31:0] rdata,      // Data to CPU
    input  wire        sel,        // Chip select
    output wire        interrupt,  // Interrupt output (pulsed on new key)
    output wire        data_ready, // Data available in FIFO
    input  wire        ps2_clk,    // PS/2 clock input (raw)
    input  wire        ps2_data    // PS/2 data input (raw)
);

    // Internal signals
    wire ps2_clk_debounced;
    wire ps2_data_debounced;
    wire [7:0] ps2_byte;
    wire valid;
    wire core_interrupt;
    wire fifo_empty;
    wire fifo_full;
    wire [7:0] fifo_data_out;

    // State machine for FIFO read and interrupt generation
    reg [7:0] ps2_value;
    reg [1:0] ps2_status;
    reg read_enable;
    reg read_buffer_full;
    reg interrupt_reg;

    localparam IDLE = 0, DELAY = 1, READ = 2, DELAY2 = 3;
    reg [2:0] state_reg;

    // Output assignments
    assign rdata = (sel && rstrb) ? {22'b0, ps2_status, ps2_value} : 32'b0;
    assign data_ready = read_buffer_full;
    assign interrupt = interrupt_reg;

    // Status bits: {fifo_full, fifo_empty}
    wire device_data_ready = ~fifo_empty;
    wire device_data_strobe = valid;  // valid pulses when new byte from decoder

    // Debounce PS/2 signals
    debounce #(
        .DEBOUNCE_CYCLES(128)
    ) ps2_clk_debounce (
        .clk(clk),
        .reset(~reset),  // Convert to active-high for core module
        .button(ps2_clk),
        .debounced_button(ps2_clk_debounced)
    );

    debounce #(
        .DEBOUNCE_CYCLES(128)
    ) ps2_data_debounce (
        .clk(clk),
        .reset(~reset),
        .button(ps2_data),
        .debounced_button(ps2_data_debounced)
    );

    // PS/2 decoder core
    ps2_decoder_core #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .PS2_CLK_HZ(10_000)
    ) ps2_core (
        .clk(clk),
        .reset(~reset),
        .ps2_clk(ps2_clk_debounced),
        .ps2_data(ps2_data_debounced),
        .int_clear(1'b0),  // Not used in this wrapper (interrupt is a pulse)
        .valid(valid),
        .interrupt(core_interrupt),  // Not used (we generate our own interrupt pulse)
        .data(ps2_byte)
    );

    // FIFO for buffering scan codes
    dual_fifo #(
        .DEPTH(2),  // 4 entries
        .WIDTH(8)
    ) fifo (
        .clk(clk),
        .rst(~reset),
        .wr_en(valid),           // Write on valid pulse from decoder
        .rd_en(read_enable),     // Read controlled by state machine
        .data_in(ps2_byte),
        .data_out(fifo_data_out),
        .empty(fifo_empty),
        .full(fifo_full)
    );

    // State machine: manages FIFO reads and interrupt generation
    // This ensures CPU gets one byte per read strobe
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state_reg <= IDLE;
            ps2_value <= 8'b11110101;
            ps2_status <= 2'b00;
            read_enable <= 0;
            read_buffer_full <= 0;
            interrupt_reg <= 0;
        end else begin
            case(state_reg)
                IDLE: begin
                    // If a key is received and our buffer isn't full, read from FIFO
                    if (device_data_strobe && ~read_buffer_full) begin
                        read_enable <= 1;
                        ps2_status <= {fifo_full, fifo_empty};
                        state_reg <= DELAY;
                    // If CPU is reading our buffer, check if more data available
                    end else if (sel && rstrb && read_buffer_full) begin
                        if (device_data_ready) begin
                            read_enable <= 1;
                            ps2_status <= {fifo_full, fifo_empty};
                            state_reg <= DELAY;
                        end else begin
                            read_buffer_full <= 0;
                        end
                    end
                end
                DELAY: begin
                    read_enable <= 0;
                    state_reg <= READ;
                end
                READ: begin
                    // FIFO output is stable after one cycle
                    ps2_value <= fifo_data_out;
                    read_buffer_full <= 1;
                    interrupt_reg <= 1;
                    state_reg <= DELAY2;
                end
                DELAY2: begin
                    interrupt_reg <= 0;
                    state_reg <= IDLE;
                end
            endcase
        end
    end

endmodule
