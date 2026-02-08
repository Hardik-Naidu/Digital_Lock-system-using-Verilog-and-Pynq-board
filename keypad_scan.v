`timescale 1ns / 1ps

module keypad_scan(
    input clk,
    input rst,
    input [3:0] col,          // active LOW
    output reg [3:0] row,     // active LOW
    output reg [3:0] key_code,
    output reg key_valid
);

    reg [19:0] cnt;
    reg [22:0] debounce_cnt;
    reg [3:0] last_col;
    reg [3:0] last_row;
    reg key_pressed;

    localparam SCAN_PERIOD   = 20'd125000;     // 1 ms @125 MHz
    localparam DEBOUNCE_TIME = 23'd2500000;    // 20 ms

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            row <= 4'b1110;
            cnt <= 0;
            debounce_cnt <= 0;
            last_col <= 4'b1111;
            last_row <= 4'b1110;
            key_pressed <= 0;
            key_code <= 4'h0;
            key_valid <= 1'b0;
        end else begin

            // Default
            if (!key_pressed)
                key_valid <= 1'b0;

            // Row scanning
            if (debounce_cnt == 0 && !key_pressed) begin
                if (cnt >= SCAN_PERIOD) begin
                    cnt <= 0;
                    row <= {row[2:0], row[3]};
                end else
                    cnt <= cnt + 1;
            end

            // Key detect + debounce
            if (col != 4'b1111 && !key_pressed) begin
                if (debounce_cnt == 0) begin
                    last_col <= col;
                    last_row <= row;
                    debounce_cnt <= 1;
                end else if (debounce_cnt < DEBOUNCE_TIME) begin
                    debounce_cnt <= debounce_cnt + 1;
                end else begin
                    key_pressed <= 1'b1;
                    key_valid   <= 1'b1;
                    debounce_cnt <= 0;

                    case ({last_row, last_col})
                        8'b1110_1110: key_code <= 4'h1;
                        8'b1110_1101: key_code <= 4'h2;
                        8'b1110_1011: key_code <= 4'h3;
                        8'b1110_0111: key_code <= 4'hA;

                        8'b1101_1110: key_code <= 4'h4;
                        8'b1101_1101: key_code <= 4'h5;
                        8'b1101_1011: key_code <= 4'h6;
                        8'b1101_0111: key_code <= 4'hB;

                        8'b1011_1110: key_code <= 4'h7;
                        8'b1011_1101: key_code <= 4'h8;
                        8'b1011_1011: key_code <= 4'h9;
                        8'b1011_0111: key_code <= 4'hC;

                        8'b0111_1110: key_code <= 4'hE; // *
                        8'b0111_1101: key_code <= 4'h0;
                        8'b0111_1011: key_code <= 4'hF; // #
                        8'b0111_0111: key_code <= 4'hD;

                        default: key_code <= 4'h0;
                    endcase
                end
            end
            else if (col == 4'b1111) begin
                debounce_cnt <= 0;
                key_pressed <= 0;
                key_valid <= 0;
            end
        end
    end
endmodule
