`default_nettype none

//
// UART Test with NO Reset Dependency
// If reset is the issue, this will bypass it
//

module uart_no_reset_test (
    input  wire clk,
    input  wire reset_n,  // Unused - for pin compatibility
    output wire uart_tx,
    output wire led_data_ready,
    output wire led_interrupt,
    output wire led_fifo_full,
    output wire led_valid,
    
    // Unused
    input  wire ps2_clk,
    input  wire ps2_data,
    output wire seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g, seg_select
);

    // Counter - always running, NO reset
    reg [24:0] counter = 0;
    
    always @(posedge clk) begin
        counter <= counter + 1;
    end
    
    // Generate trigger every 0.5 seconds
    wire send_trigger = (counter == 25'd0);
    
    // UART TX module - NO reset used
    reg uart_tx_start = 0;
    wire uart_tx_busy;
    
    uart_tx #(
        .CLKS_PER_BIT(217)
    ) uart_inst (
        .clk(clk),
        .rst_n(1'b1),  // Never in reset!
        .tx_start(uart_tx_start),
        .tx_data(8'h55),
        .tx(uart_tx),
        .tx_busy(uart_tx_busy)
    );
    
    // Simple: pulse tx_start on trigger
    always @(posedge clk) begin
        uart_tx_start <= send_trigger && !uart_tx_busy;
    end
    
    // LEDs (inverted for common anode)
    assign led_data_ready = ~counter[23];       // 3 Hz blink
    assign led_interrupt  = ~uart_tx_busy;      // ON during TX
    assign led_fifo_full  = ~counter[22];       // 6 Hz blink
    assign led_valid      = ~send_trigger;      // Flash on trigger
    
    // Unused
    assign seg_a = 1'b1;
    assign seg_b = 1'b1;
    assign seg_c = 1'b1;
    assign seg_d = 1'b1;
    assign seg_e = 1'b1;
    assign seg_f = 1'b1;
    assign seg_g = 1'b1;
    assign seg_select = 1'b0;

endmodule

