// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module my_uart_rx #(
    parameter int BAUDRATE,
    parameter int FREQUENCY
) (
    input logic clk,
    input logic rst,
    input logic rx,
    output logic [7:0] data,
    output logic valid
);
    localparam int WAIT_CYCLES = FREQUENCY / BAUDRATE;

    logic [$clog2(WAIT_CYCLES+1)-1 : 0] counter;

    typedef enum {
        ST_IDLE,
        ST_CHECK_START,
        ST_READ_DATA,
        ST_CHECK_STOP
    } my_uart_states_t;

    my_uart_states_t cur_state, next_state;

    logic transitioning;
    assign transitioning = cur_state != next_state;

    logic [2:0] current_bit;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) cur_state <= ST_IDLE;
        else cur_state <= next_state;
    end

    always_comb begin
        next_state = cur_state;
        case (cur_state)
            ST_IDLE: begin
                if (rx == 1'b0) next_state = ST_CHECK_START;
            end
            ST_CHECK_START: begin
                if (counter == 0) begin
                    if (rx == 1'b0) next_state = ST_READ_DATA;
                    else next_state = ST_IDLE;
                end
            end
            ST_READ_DATA: begin
                if (counter == 0 && current_bit == 7) next_state = ST_CHECK_STOP;
            end
            ST_CHECK_STOP: begin
                if (counter == 0) next_state = ST_IDLE;
            end
            default: next_state = ST_IDLE;
        endcase
    end

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            counter <= '0;
            current_bit <= '0;
            data <= 1'b0;
            valid <= 1'b0;
        end else begin
            valid <= 1'b0;

            case (cur_state)
                ST_IDLE: begin
                    counter <= '0;

                    if (transitioning) counter <= WAIT_CYCLES / 2;
                end
                ST_CHECK_START: begin
                    counter <= counter - 1;

                    if (transitioning) begin
                        counter <= WAIT_CYCLES;
                        current_bit <= '0;
                    end
                end
                ST_READ_DATA: begin
                    counter <= counter - 1;

                    if (counter == 0) begin
                        data[current_bit] <= rx;
                        current_bit <= current_bit + 1;
                        counter <= WAIT_CYCLES;
                    end

                    if (transitioning) counter <= WAIT_CYCLES;
                end
                ST_CHECK_STOP: begin
                    counter <= counter - 1;

                    if (transitioning) begin
                        if (rx == 1'b1) valid <= 1'b1;
                    end
                end
                default: begin
                    data  <= 'x;
                    valid <= 'x;
                end
            endcase
        end
    end

endmodule
