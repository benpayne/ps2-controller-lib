// PS/2 Test - Direct instantiation (bypassing FemtoRV wrapper)
// Uses core modules directly with 7-segment display for debugging
`default_nettype none

// Include core modules directly
`include "rtl/ps2_decoder_core.v"
`include "rtl/debounce.v"
`include "rtl/dual_fifo.v"
`include "seven_seg_driver.v"

module ps2_direct_with_display (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output wire       uart_tx,
    output wire       led_data_ready,
    output wire       led_interrupt,
    output wire       led_fifo_full,
    output wire       led_valid,
    
    // 7-Segment Display
    output wire       seg_a,
    output wire       seg_b,
    output wire       seg_c,
    output wire       seg_d,
    output wire       seg_e,
    output wire       seg_f,
    output wire       seg_g,
    output wire       seg_select
);

    // Debounced PS/2 signals
    wire ps2_clk_debounced;
    wire ps2_data_debounced;

    // PS/2 decoder outputs
    wire [7:0] ps2_byte;
    wire valid;
    wire ps2_interrupt;

    // FIFO signals
    wire fifo_empty;
    wire fifo_full;
    wire [7:0] fifo_data_out;
    reg fifo_rd_en;

    // UART signals
    reg         uart_tx_start;
    reg  [7:0]  uart_tx_data;
    wire        uart_tx_busy;

    // State machine
    localparam IDLE          = 4'd0;
    localparam WAIT_CYCLE    = 4'd1;
    localparam CAPTURE       = 4'd2;
    localparam PREP_HEX      = 4'd3;  // Wait for captured_scancode to be valid
    localparam SEND_HEX_HIGH = 4'd4;
    localparam WAIT_HEX_HIGH = 4'd5;
    localparam SEND_HEX_LOW  = 4'd6;
    localparam WAIT_HEX_LOW  = 4'd7;

    reg [3:0]   state;
    reg [7:0]   captured_scancode;
    
    // Function to convert 4-bit hex to ASCII
    function [7:0] hex_to_ascii(input [3:0] hex);
        begin
            if (hex < 10)
                hex_to_ascii = 8'h30 + hex;  // '0' to '9'
            else
                hex_to_ascii = 8'h41 + (hex - 10);  // 'A' to 'F'
        end
    endfunction

    // Debounce PS/2 signals
    debounce #(
        .DEBOUNCE_CYCLES(128)
    ) ps2_clk_debounce (
        .clk(clk),
        .reset(~reset_n),
        .button(ps2_clk),
        .debounced_button(ps2_clk_debounced)
    );

    debounce #(
        .DEBOUNCE_CYCLES(128)
    ) ps2_data_debounce (
        .clk(clk),
        .reset(~reset_n),
        .button(ps2_data),
        .debounced_button(ps2_data_debounced)
    );

    // PS/2 decoder core
    ps2_decoder_core #(
        .CLK_FREQ_HZ(25_000_000),
        .PS2_CLK_HZ(10_000)
    ) ps2_core (
        .clk(clk),
        .reset(~reset_n),
        .ps2_clk(ps2_clk_debounced),
        .ps2_data(ps2_data_debounced),
        .int_clear(1'b0),
        .valid(valid),
        .interrupt(ps2_interrupt),
        .data(ps2_byte)
    );

    // FIFO for buffering
    dual_fifo #(
        .DEPTH(2),
        .WIDTH(8)
    ) fifo (
        .clk(clk),
        .rst(~reset_n),
        .wr_en(valid),           // Write on valid pulse from decoder
        .rd_en(fifo_rd_en),      // We control reads
        .data_in(ps2_byte),
        .data_out(fifo_data_out),
        .empty(fifo_empty),
        .full(fifo_full)
    );

    // UART TX (use our fixed uart_tx.v)
    uart_tx #(
        .CLKS_PER_BIT(217)
    ) uart_inst (
        .clk(clk),
        .rst_n(reset_n),
        .tx_start(uart_tx_start),
        .tx_data(uart_tx_data),
        .tx(uart_tx),
        .tx_busy(uart_tx_busy)
    );
    
    // 7-Segment Display - shows last captured scan code
    reg [7:0] display_value;
    wire [6:0] segments_wire;
    wire digit_select_wire;
    
    seven_seg_driver #(
        .CLK_FREQ_HZ(25_000_000),
        .REFRESH_HZ(1000)
    ) seven_seg (
        .clk(clk),
        .reset_n(reset_n),
        .value(display_value),
        .segments(segments_wire),
        .digit_select(digit_select_wire)
    );
    
    // Connect 7-segment outputs (inverted for common anode)
    assign {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} = ~segments_wire;
    assign seg_select = ~digit_select_wire;  // Invert to swap digit order

    // State machine: when FIFO has data, read it and send via UART
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            uart_tx_start <= 0;
            uart_tx_data <= 0;
            captured_scancode <= 0;
            fifo_rd_en <= 0;
            display_value <= 8'hFF;  // Initialize display
        end else begin
            case (state)
                IDLE: begin
                    uart_tx_start <= 0;
                    fifo_rd_en <= 0;

                    // When FIFO has data, start read
                    if (!fifo_empty) begin
                        fifo_rd_en <= 1;
                        state <= WAIT_CYCLE;
                    end
                end

                WAIT_CYCLE: begin
                    // fifo_rd_en was high, now wait for data
                    fifo_rd_en <= 0;
                    state <= CAPTURE;
                end

                CAPTURE: begin
                    // FIFO output should be stable NOW (two cycles after asserting rd_en)
                    // Capture to register and display
                    captured_scancode <= fifo_data_out;
                    display_value <= fifo_data_out;
                    state <= PREP_HEX;
                end
                
                PREP_HEX: begin
                    // Wait one cycle for captured_scancode to be valid
                    state <= SEND_HEX_HIGH;
                end

                SEND_HEX_HIGH: begin
                    // Now captured_scancode is valid - send high nibble as ASCII hex
                    uart_tx_data <= hex_to_ascii(captured_scancode[7:4]);
                    uart_tx_start <= 1;
                    state <= WAIT_HEX_HIGH;
                end
                
                WAIT_HEX_HIGH: begin
                    // Clear start signal
                    uart_tx_start <= 0;
                    // Wait for transmission to complete (busy goes high, then low)
                    // Don't check busy on first cycle - let it go high first
                    if (uart_tx_start == 0 && !uart_tx_busy) begin
                        state <= SEND_HEX_LOW;
                    end
                end

                SEND_HEX_LOW: begin
                    // Send low nibble as ASCII hex
                    uart_tx_data <= hex_to_ascii(captured_scancode[3:0]);
                    uart_tx_start <= 1;
                    state <= WAIT_HEX_LOW;
                end
                
                WAIT_HEX_LOW: begin
                    // Clear start signal
                    uart_tx_start <= 0;
                    // Wait for transmission to complete
                    if (uart_tx_start == 0 && !uart_tx_busy) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Heartbeat
    reg [24:0] heartbeat_counter;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            heartbeat_counter <= 0;
        else
            heartbeat_counter <= heartbeat_counter + 1;
    end
    wire heartbeat = heartbeat_counter[23];

    // LED outputs - INVERTED for active-low
    assign led_data_ready = ~heartbeat;          // LED1: Heartbeat
    assign led_interrupt  = ~ps2_interrupt;      // LED2: Interrupt
    assign led_fifo_full  = ~fifo_full;          // LED3: FIFO full
    assign led_valid      = ~fifo_empty;         // LED4: FIFO has data

endmodule
