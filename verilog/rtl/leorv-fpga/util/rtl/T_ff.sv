// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module T_ff (
    input resetn,
    input clk,
    input in,

    output logic out
);
    always_ff @(posedge clk) begin
        if (!resetn) begin
            out <= 1;
        end else if (in) begin
            out <= !out;
        end
    end

endmodule
