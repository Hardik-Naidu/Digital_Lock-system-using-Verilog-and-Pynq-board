`timescale 1ns / 1ps

module digilock(
    input clk,
    input rst,
    input key_valid,
    input [3:0] key_code,
    output reg led0,
    output reg [2:0] wrong_leds
);

    // =========================
    // State encoding
    // =========================
    localparam LOCKED           = 3'd0,
               UNLOCKED         = 3'd1,
               LOCKED_OUT       = 3'd2,
               CHANGE_PASS_OLD  = 3'd3,
               CHANGE_PASS_NEW  = 3'd4,
               CHANGE_PASS_CONF = 3'd5;

    reg [2:0] state, prev_state;

    // =========================
    // Registers
    // =========================
    reg [15:0] stored_pass, entered_pass, new_pass;
    reg [2:0] digit_cnt, wrong_cnt;

    reg [31:0] lockout_timer;
    reg [26:0] blink_cnt;     // unified blink counter

    // =========================
    // Timing constants
    // =========================
    localparam LOCKOUT_TIME = 32'd375_000_000;   // 3 seconds @125MHz
    localparam BLINK_HALF   = 27'd62_500_000;    // 0.5 second

    // =========================
    // key_valid edge detect
    // =========================
    reg key_valid_d;
    wire key_pulse = key_valid & ~key_valid_d;

    always @(posedge clk or posedge rst)
        if (rst) key_valid_d <= 1'b0;
        else     key_valid_d <= key_valid;

    // =========================
    // Key meaning
    // =========================
    wire is_digit   = (key_code <= 4'd9);
    wire is_clear   = (key_code == 4'hA); // *
    wire is_confirm = (key_code == 4'hB); // #

    // =========================
    // Blink counter (used in LOCKED_OUT + CHANGE PASS)
    // =========================
    always @(posedge clk or posedge rst) begin
        if (rst)
            blink_cnt <= 0;
        else if (state == LOCKED_OUT ||
                 state == CHANGE_PASS_OLD ||
                 state == CHANGE_PASS_NEW ||
                 state == CHANGE_PASS_CONF)
            blink_cnt <= blink_cnt + 1;
        else
            blink_cnt <= 0;
    end

    wire blink = (blink_cnt < BLINK_HALF);

    // =========================
    // FSM
    // =========================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= LOCKED;
            prev_state <= LOCKED;
            stored_pass <= 16'h1234;
            entered_pass <= 0;
            new_pass <= 0;
            digit_cnt <= 0;
            wrong_cnt <= 0;
            lockout_timer <= 0;
        end else begin

            // Clear entry on state entry
            if (state != prev_state) begin
                entered_pass <= 0;
                digit_cnt <= 0;
            end
            prev_state <= state;

            case (state)

                // =========================
                // LOCKED
                // =========================
                LOCKED: if (key_pulse) begin
                    if (is_digit && digit_cnt < 4) begin
                        entered_pass <= {entered_pass[11:0], key_code};
                        digit_cnt <= digit_cnt + 1;
                    end
                    else if (is_clear) begin
                        entered_pass <= 0;
                        digit_cnt <= 0;
                    end
                    else if (is_confirm && digit_cnt == 4) begin
                        if (entered_pass == stored_pass) begin
                            state <= UNLOCKED;
                            wrong_cnt <= 0;
                        end else begin
                            if (wrong_cnt == 2) begin
                                state <= LOCKED_OUT;
                                lockout_timer <= 0;
                                wrong_cnt <= 3;
                            end else
                                wrong_cnt <= wrong_cnt + 1;
                        end
                    end
                end

                // =========================
                // UNLOCKED
                // =========================
                UNLOCKED: if (key_pulse) begin
                    if (is_confirm)
                        state <= LOCKED;          // 🔒 manual lock
                    else if (is_clear)
                        state <= CHANGE_PASS_OLD; // 🔑 change password
                end

                // =========================
                // LOCKED OUT (3s blink)
                // =========================
                LOCKED_OUT: begin
                    if (lockout_timer >= LOCKOUT_TIME) begin
                        state <= LOCKED;
                        wrong_cnt <= 0;
                        lockout_timer <= 0;
                    end else
                        lockout_timer <= lockout_timer + 1;
                end

                // =========================
                // CHANGE PASSWORD - OLD
                // =========================
                CHANGE_PASS_OLD: if (key_pulse) begin
                    if (is_digit && digit_cnt < 4) begin
                        entered_pass <= {entered_pass[11:0], key_code};
                        digit_cnt <= digit_cnt + 1;
                    end
                    else if (is_confirm)
                        state <= (digit_cnt == 4 && entered_pass == stored_pass)
                                  ? CHANGE_PASS_NEW : LOCKED;
                    else if (is_clear)
                        state <= LOCKED;
                end

                // =========================
                // CHANGE PASSWORD - NEW
                // =========================
                CHANGE_PASS_NEW: if (key_pulse) begin
                    if (is_digit && digit_cnt < 4) begin
                        entered_pass <= {entered_pass[11:0], key_code};
                        digit_cnt <= digit_cnt + 1;
                    end
                    else if (is_confirm && digit_cnt == 4) begin
                        new_pass <= entered_pass;
                        state <= CHANGE_PASS_CONF;
                    end
                    else if (is_clear)
                        state <= LOCKED;
                end

                // =========================
                // CHANGE PASSWORD - CONFIRM
                // =========================
                CHANGE_PASS_CONF: if (key_pulse) begin
                    if (is_digit && digit_cnt < 4) begin
                        entered_pass <= {entered_pass[11:0], key_code};
                        digit_cnt <= digit_cnt + 1;
                    end
                    else if (is_confirm) begin
                        if (digit_cnt == 4 && entered_pass == new_pass) begin
                            stored_pass <= new_pass;   // ✅ password updated
                            state <= UNLOCKED;
                            wrong_cnt <= 0;
                        end else
                            state <= LOCKED;
                    end
                    else if (is_clear)
                        state <= LOCKED;
                end
            endcase
        end
    end

    // =========================
    // OUTPUT LOGIC
    // =========================
    always @(*) begin
        case (state)
            UNLOCKED: begin
                led0 = 1'b1;
                wrong_leds = 3'b000;
            end

            LOCKED_OUT: begin
                led0 = 1'b0;
                wrong_leds = blink ? 3'b111 : 3'b000; // ✅ BLINK ALL 3
            end

            CHANGE_PASS_OLD,
            CHANGE_PASS_NEW,
            CHANGE_PASS_CONF: begin
                led0 = blink;          // blink while changing password
                wrong_leds = 3'b000;
            end

            default: begin
                led0 = 1'b0;
                wrong_leds[0] = (wrong_cnt >= 1);
                wrong_leds[1] = (wrong_cnt >= 2);
                wrong_leds[2] = (wrong_cnt >= 3);
            end
        endcase
    end

endmodule
