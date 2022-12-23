// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module debouncer #(
    parameter int MAX_COUNT = 512
) (
    input clk,
    input resetn,
    input in,

    output logic out
);

    logic [$clog2(MAX_COUNT+1)-1:0] counter;

    always_ff @(posedge clk) begin
        if (!resetn || !in) begin
            counter <= 0;
        end else begin
            if (counter < MAX_COUNT) begin
                counter <= counter + 1;
            end
        end
    end

    assign out = (counter == MAX_COUNT);

endmodule
