`default_nettype none

//
// Simple Periodic UART Test
// Sends one byte every 0.5 seconds
// LED shows when transmission starts
//

module uart_simple_test (
    input  wire clk,
    input  wire reset_n,
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

    // Counter - 0.5 second at 25 MHz
    reg [24:0] counter;
    reg send_trigger;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter <= 0;
            send_trigger <= 0;
        end else begin
            if (counter >= 12_500_000) begin  // 0.5 second
                counter <= 0;
                send_trigger <= 1;
            end else begin
                counter <= counter + 1;
                send_trigger <= 0;
            end
        end
    end
    
    // UART TX module
    reg uart_tx_start;
    wire uart_tx_busy;
    
    uart_tx #(
        .CLKS_PER_BIT(217)  // 25MHz / 115200
    ) uart_inst (
        .clk(clk),
        .rst_n(reset_n),
        .tx_start(uart_tx_start),
        .tx_data(8'h55),  // Always send 0x55
        .tx(uart_tx),
        .tx_busy(uart_tx_busy)
    );
    
    // Simple: pulse tx_start when trigger fires
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            uart_tx_start <= 0;
        end else begin
            uart_tx_start <= send_trigger;
        end
    end
    
    // LEDs (inverted for common anode)
    assign led_data_ready = ~counter[23];       // Heartbeat 3 Hz
    assign led_interrupt  = ~uart_tx_busy;      // ON during TX
    assign led_fifo_full  = ~send_trigger;      // Flash when triggering
    assign led_valid      = ~uart_tx;           // Mirror UART TX
    
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

