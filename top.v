`timescale 1ns / 1ps

module top(
    input clk,
    input rst,
    input [3:0] col,
    output [3:0] row,
    output led0,
    output [2:0] wrong_leds
);

    wire [3:0] key_code;
    wire key_valid;

    keypad_scan U1 (
        .clk(clk),
        .rst(rst),
        .col(col),
        .row(row),
        .key_code(key_code),
        .key_valid(key_valid)
    );

    digilock U2 (
        .clk(clk),
        .rst(rst),
        .key_valid(key_valid),
        .key_code(key_code),
        .led0(led0),
        .wrong_leds(wrong_leds)
    );
endmodule
