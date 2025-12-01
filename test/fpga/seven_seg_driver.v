// 7-Segment Display Driver Module
// Drives 2-digit 7-segment display with multiplexing
// Displays 8-bit value as 2 hex digits
`default_nettype none

module seven_seg_driver #(
    parameter CLK_FREQ_HZ = 25_000_000,
    parameter REFRESH_HZ = 1000  // Multiplex frequency
) (
    input wire clk,
    input wire reset_n,
    input wire [7:0] value,      // Value to display (0x00 to 0xFF)
    output reg [6:0] segments,   // Segments A-G (active high for common cathode)
    output reg digit_select      // 0=digit1, 1=digit2
);

    // Calculate refresh divider
    localparam REFRESH_DIV = CLK_FREQ_HZ / (REFRESH_HZ * 2);  // *2 for 2 digits

    reg [$clog2(REFRESH_DIV)-1:0] refresh_counter;
    reg [3:0] current_digit;  // Current hex digit to display (0-F)

    // Hex to 7-segment decoder
    // Segment order: GFEDCBA (bit 6 to bit 0)
    //     AAA
    //    F   B
    //     GGG
    //    E   C
    //     DDD
    function [6:0] hex_to_seg(input [3:0] hex);
        case (hex)
            4'h0: hex_to_seg = 7'b0111111;  // 0
            4'h1: hex_to_seg = 7'b0000110;  // 1
            4'h2: hex_to_seg = 7'b1011011;  // 2
            4'h3: hex_to_seg = 7'b1001111;  // 3
            4'h4: hex_to_seg = 7'b1100110;  // 4
            4'h5: hex_to_seg = 7'b1101101;  // 5
            4'h6: hex_to_seg = 7'b1111101;  // 6
            4'h7: hex_to_seg = 7'b0000111;  // 7
            4'h8: hex_to_seg = 7'b1111111;  // 8
            4'h9: hex_to_seg = 7'b1101111;  // 9
            4'hA: hex_to_seg = 7'b1110111;  // A
            4'hB: hex_to_seg = 7'b1111100;  // b
            4'hC: hex_to_seg = 7'b0111001;  // C
            4'hD: hex_to_seg = 7'b1011110;  // d
            4'hE: hex_to_seg = 7'b1111001;  // E
            4'hF: hex_to_seg = 7'b1110001;  // F
        endcase
    endfunction

    // Multiplex between digits
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            refresh_counter <= 0;
            digit_select <= 0;
            segments <= 0;
            current_digit <= 0;
        end else begin
            if (refresh_counter >= REFRESH_DIV - 1) begin
                refresh_counter <= 0;
                digit_select <= ~digit_select;

                // Select which digit to display (swapped - hardware is reversed)
                if (digit_select) begin
                    // Display low nibble (right digit / least significant)
                    current_digit <= value[3:0];
                end else begin
                    // Display high nibble (left digit / most significant)
                    current_digit <= value[7:4];
                end
            end else begin
                refresh_counter <= refresh_counter + 1;
            end

            // Update segments based on current digit
            segments <= hex_to_seg(current_digit);
        end
    end

endmodule
