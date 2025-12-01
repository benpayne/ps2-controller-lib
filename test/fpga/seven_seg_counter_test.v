// Simple 7-Segment Display Test - Counter 0x00 to 0xFF
// Counts at 1 Hz to verify display is working correctly
`default_nettype none

`include "seven_seg_driver.v"

module seven_seg_counter_test (
    input  wire       clk,
    input  wire       reset_n,
    
    // Unused PS/2 inputs
    input  wire       ps2_clk,
    input  wire       ps2_data,
    
    // Unused UART
    output wire       uart_tx,
    
    // LEDs
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

    // Counter that increments every second
    reg [7:0] display_value;
    reg [24:0] counter;  // 25 bits for counting to 25M (1 second at 25 MHz)
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            display_value <= 8'h00;
            counter <= 0;
        end else begin
            if (counter >= 25_000_000 - 1) begin
                counter <= 0;
                display_value <= display_value + 1;  // Increment every second
            end else begin
                counter <= counter + 1;
            end
        end
    end
    
    // 7-Segment Display Driver
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
    
    // Unused outputs
    assign uart_tx = 1'b1;
    assign led_data_ready = ~counter[23];  // Blink heartbeat
    assign led_interrupt = 1'b1;
    assign led_fifo_full = 1'b1;
    assign led_valid = 1'b1;

endmodule

