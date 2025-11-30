// UART Only Test - Send 0x55 continuously
`default_nettype none

`include "uart_tx_simple.v"

module ps2_test_top (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output wire       uart_tx,
    output wire       led_data_ready,
    output wire       led_interrupt,
    output wire       led_fifo_full,
    output wire       led_valid
);

    // UART signals
    reg         uart_tx_start;
    wire        uart_tx_busy;

    // UART TX
    uart_tx_simple #(
        .CLKS_PER_BIT(217)
    ) uart_inst (
        .clk(clk),
        .reset_n(reset_n),
        .tx_start(uart_tx_start),
        .tx_data(8'h55),
        .tx(uart_tx),
        .tx_busy(uart_tx_busy)
    );

    // Just pulse uart_tx_start continuously
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            uart_tx_start <= 0;
        else
            uart_tx_start <= ~uart_tx_busy;  // Start when not busy
    end

    // Heartbeat LED
    reg [24:0] counter;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            counter <= 0;
        else
            counter <= counter + 1;
    end

    assign led_data_ready = ~counter[23];
    assign led_interrupt  = 1'b1;
    assign led_fifo_full  = 1'b1;
    assign led_valid      = ~uart_tx_busy;

endmodule
