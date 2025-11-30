`default_nettype none

//
// Simple UART TX Test
// Sends 0x55 every second to verify UART hardware and wiring
//

module uart_test_top (
    input  wire clk,
    input  wire reset_n,
    output wire uart_tx,
    output wire led_data_ready,
    output wire led_interrupt,
    output wire led_fifo_full,
    output wire led_valid,
    
    // Unused PS/2 pins (tie off)
    input  wire ps2_clk,
    input  wire ps2_data,
    
    // Unused 7-segment pins
    output wire seg_a,
    output wire seg_b,
    output wire seg_c,
    output wire seg_d,
    output wire seg_e,
    output wire seg_f,
    output wire seg_g,
    output wire seg_select
);

    // Heartbeat counter (1 second at 25 MHz)
    reg [24:0] heartbeat_counter;
    reg heartbeat_pulse;
    reg [19:0] pulse_stretch;  // Stretch pulse for 0.01s so it's visible
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            heartbeat_counter <= 0;
            heartbeat_pulse <= 0;
            pulse_stretch <= 0;
        end else begin
            if (heartbeat_counter >= 25_000_000 - 1) begin
                heartbeat_counter <= 0;
                heartbeat_pulse <= 1;
                pulse_stretch <= 250_000;  // 0.01 second at 25 MHz
            end else begin
                heartbeat_counter <= heartbeat_counter + 1;
                heartbeat_pulse <= 0;
            end
            
            // Count down pulse stretch
            if (pulse_stretch > 0) begin
                pulse_stretch <= pulse_stretch - 1;
            end
        end
    end
    
    wire pulse_visible = (pulse_stretch > 0);
    
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
    
    // Simple state machine: send 0x55 every second
    localparam IDLE = 0;
    localparam SEND = 1;
    localparam WAIT = 2;
    
    reg [1:0] state;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            uart_tx_start <= 0;
            uart_tx_data <= 8'h55;
        end else begin
            case (state)
                IDLE: begin
                    uart_tx_start <= 0;
                    if (heartbeat_pulse) begin
                        uart_tx_data <= 8'h55;  // Test pattern
                        state <= SEND;
                    end
                end
                
                SEND: begin
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
    
    // LED indicators (inverted for common anode LEDs)
    // LEDs are active LOW: 0=ON, 1=OFF
    assign led_data_ready = ~heartbeat_counter[23];  // Blink fast (~3 Hz)
    assign led_interrupt  = ~uart_tx_busy;           // ON when transmitting
    assign led_fifo_full  = ~heartbeat_counter[22];  // Blink faster (~6 Hz) 
    assign led_valid      = ~pulse_visible;          // Flash for 0.01s every second
    
    // Tie off unused 7-segment display
    assign seg_a = 1'b1;
    assign seg_b = 1'b1;
    assign seg_c = 1'b1;
    assign seg_d = 1'b1;
    assign seg_e = 1'b1;
    assign seg_f = 1'b1;
    assign seg_g = 1'b1;
    assign seg_select = 1'b0;

endmodule

