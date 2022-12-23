// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module edge_detection #(
    parameter bit RISING_EDGE  = 1,
    parameter bit FALLING_EDGE = 0
) (
    input clk,
    input in,

    output logic out
);

    reg old_in;

    always_ff @(posedge clk) begin
        old_in <= in;
    end

    logic rising_edge;
    logic falling_edge;

    assign rising_edge  = ~old_in && in;
    assign falling_edge = old_in && ~in;

    generate
        if (RISING_EDGE && FALLING_EDGE) begin : gen_both_edges
            assign out = rising_edge || falling_edge;
        end else if (RISING_EDGE) begin : gen_rising_edge
            assign out = rising_edge;
        end else if (FALLING_EDGE) begin : gen_falling_edge
            assign out = falling_edge;
        end
    endgenerate

endmodule
