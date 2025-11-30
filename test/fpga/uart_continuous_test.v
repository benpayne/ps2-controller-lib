`default_nettype none

//
// Continuous UART Test
// Sends 0xAA continuously (every ~70us) to flood the serial port
// If UART works at all, you'll see garbage/data immediately
//

module uart_continuous_test (
    input  wire clk,
    input  wire reset_n,
    output wire uart_tx,
    output wire led_data_ready,
    output wire led_interrupt,
    output wire led_fifo_full,
    output wire led_valid,
    
    // Unused inputs
    input  wire ps2_clk,
    input  wire ps2_data,
    
    // Unused 7-segment outputs
    output wire seg_a,
    output wire seg_b,
    output wire seg_c,
    output wire seg_d,
    output wire seg_e,
    output wire seg_f,
    output wire seg_g,
    output wire seg_select
);

    // Counter for heartbeat
    reg [24:0] counter;
    
    always @(posedge clk) begin
        if (!reset_n)
            counter <= 0;
        else
            counter <= counter + 1;
    end
    
    // UART TX module
    reg uart_tx_start;
    reg [7:0] uart_tx_data;
    wire uart_tx_busy;
    
    uart_tx #(
        .CLKS_PER_BIT(217)  // 25MHz / 115200
    ) uart_inst (
        .clk(clk),
        .rst_n(reset_n),
        .tx_start(uart_tx_start),
        .tx_data(uart_tx_data),
        .tx(uart_tx),
        .tx_busy(uart_tx_busy)
    );
    
    // State machine: send continuously
    localparam IDLE = 0;
    localparam SEND = 1;
    localparam WAIT = 2;
    
    reg [1:0] state;
    reg [7:0] test_byte;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            uart_tx_start <= 0;
            uart_tx_data <= 8'hAA;
            test_byte <= 8'h55;
        end else begin
            case (state)
                IDLE: begin
                    uart_tx_start <= 0;
                    // Send immediately (no delay)
                    state <= SEND;
                    // Alternate between 0x55 and 0xAA for pattern
                    test_byte <= (test_byte == 8'h55) ? 8'hAA : 8'h55;
                end
                
                SEND: begin
                    uart_tx_data <= test_byte;
                    uart_tx_start <= 1;
                    state <= WAIT;
                end
                
                WAIT: begin
                    uart_tx_start <= 0;
                    if (!uart_tx_busy) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // LED indicators (inverted for common anode)
    assign led_data_ready = ~counter[23];      // 3 Hz blink
    assign led_interrupt  = ~uart_tx_busy;     // ON during transmission (should be mostly ON)
    assign led_fifo_full  = ~counter[22];      // 6 Hz blink
    assign led_valid      = ~uart_tx;          // Mirrors UART TX line
    
    // Tie off 7-segment
    assign seg_a = 1'b1;
    assign seg_b = 1'b1;
    assign seg_c = 1'b1;
    assign seg_d = 1'b1;
    assign seg_e = 1'b1;
    assign seg_f = 1'b1;
    assign seg_g = 1'b1;
    assign seg_select = 1'b0;

endmodule

