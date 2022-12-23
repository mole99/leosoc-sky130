// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module my_uart_tx #(
    parameter int BAUDRATE,
    parameter int FREQUENCY
) (
    input logic clk,
    input logic rst,
    input logic [7:0] data,
    input logic start,
    output logic tx,
    output logic busy
);
    localparam int WAIT_CYCLES = FREQUENCY / BAUDRATE;

    logic [$clog2(WAIT_CYCLES+1)-1 : 0] counter;

    typedef enum {
        ST_IDLE,
        ST_SEND_START,
        ST_SEND_DATA,
        ST_SEND_STOP
    } my_uart_states_t;

    my_uart_states_t cur_state, next_state;

    logic transitioning;
    assign transitioning = cur_state != next_state;

    logic [2:0] current_bit;
    logic [7:0] data_stored;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) cur_state <= ST_IDLE;
        else cur_state <= next_state;
    end

    always_comb begin
        next_state = cur_state;
        case (cur_state)
            ST_IDLE: begin
                if (start == 1'b1) next_state = ST_SEND_START;
            end
            ST_SEND_START: begin
                if (counter == 0) begin
                    next_state = ST_SEND_DATA;
                end
            end
            ST_SEND_DATA: begin
                if (counter == 0 && current_bit == 7) next_state = ST_SEND_STOP;
            end
            ST_SEND_STOP: begin
                if (counter == 0) next_state = ST_IDLE;
            end
            default: next_state = ST_IDLE;
        endcase
    end

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            counter <= '0;
            current_bit <= '0;
            busy <= 1'b0;
        end else begin
            busy <= 1'b1;

            case (cur_state)
                ST_IDLE: begin
                    tx <= 1'b1;
                    counter <= '0;
                    busy <= 1'b0;

                    if (transitioning) begin
                        data_stored <= data;
                        counter <= WAIT_CYCLES;
                        busy <= 1'b1;
                    end
                end
                ST_SEND_START: begin
                    tx <= 1'b0;
                    counter <= counter - 1;

                    if (transitioning) begin
                        counter <= WAIT_CYCLES;
                        current_bit <= 0;
                    end
                end
                ST_SEND_DATA: begin
                    tx <= data_stored[current_bit];
                    counter <= counter - 1;

                    if (counter == 0) begin
                        current_bit <= current_bit + 1;
                        counter <= WAIT_CYCLES;
                    end

                    if (transitioning) counter <= WAIT_CYCLES;
                end
                ST_SEND_STOP: begin
                    tx <= 1'b1;
                    counter <= counter - 1;
                end
                default: begin
                    busy <= 'x;
                    tx   <= 'x;
                end
            endcase
        end
    end

endmodule
