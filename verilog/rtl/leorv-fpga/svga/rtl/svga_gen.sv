// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module svga_gen (
    input reset,
    input video_clk, // 40 MHz for SVGA

    output logic signed [10:0] screen_x,  // -1024/1023
    output logic signed [10:0] screen_y,  // -1024/1023

    output logic horizontal_enable,
    output logic vertical_enable,
    output logic enable,

    output logic horizontal_pulse,
    output logic vertical_pulse,

    output logic horizontal_sync,
    output logic vertical_sync,

    output logic frame
);
    localparam FREQUENCY = 40_000_000;
    localparam WIDTH = 800;
    localparam HEIGHT = 600;

    localparam H_FRONT_PORCH = 40;
    localparam H_SYNC_WIDTH = 128;
    localparam H_BACK_PORCH = 88;

    localparam V_FRONT_PORCH = 1;
    localparam V_SYNC_WIDTH = 4;
    localparam V_BACK_PORCH = 23;

    logic signed [10:0] tmp_x; // -1024/1023
    logic signed [10:0] tmp_y; // -1024/1023

    always_ff @(posedge video_clk, posedge reset) begin
        if (reset) begin
            tmp_x <= 0 - H_FRONT_PORCH;
            tmp_y <= 0 - V_FRONT_PORCH;

            screen_x <= 0 - H_FRONT_PORCH;
            screen_y <= 0 - V_FRONT_PORCH;
            frame <= 1'b0;
        end else begin
            frame <= 1'b0;
            tmp_x <= tmp_x + 1;

            // Have we reached the right side?
            if (tmp_x >= WIDTH + H_SYNC_WIDTH + H_BACK_PORCH - 1) begin
                tmp_x <= 0 - H_FRONT_PORCH;
                tmp_y <= tmp_y + 1;

                // Have we reached the last line?
                if (tmp_y >= HEIGHT + V_SYNC_WIDTH + V_BACK_PORCH - 1) begin
                    tmp_y <= 0 - V_FRONT_PORCH;
                    frame <= 1'b1;
                end

            end

            // Delay coordinates to sync with other signals
            screen_x <= tmp_x;
            screen_y <= tmp_y;
        end
    end

    always_ff @(posedge video_clk, posedge reset) begin
        if (reset) begin
            horizontal_sync <= '0;
            vertical_sync <= '0;

            horizontal_enable <= '0;
            vertical_enable <= '0;
            enable <= '0;

            horizontal_pulse <= '0;
            vertical_pulse <= '0;
        end else begin
            horizontal_sync <= tmp_x >= WIDTH && tmp_x < (WIDTH + H_SYNC_WIDTH);
            vertical_sync <= tmp_y >= HEIGHT && tmp_y < (HEIGHT + V_SYNC_WIDTH);

            horizontal_enable <= tmp_x >= 0 && tmp_x < WIDTH;
            vertical_enable <= tmp_y >= 0 && tmp_y < HEIGHT;
            enable <= tmp_x >= 0 && tmp_x < WIDTH && tmp_y >= 0 && tmp_y < HEIGHT;

            horizontal_pulse <= tmp_x == 0;
            vertical_pulse <= (tmp_x == 0 && tmp_y == 0);
        end
    end

endmodule
