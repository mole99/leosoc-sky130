// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module svga_gen_top #(
    parameter bit [12:0] FRAME_BUFFER_START = 0 // 75/2*100-1;
) (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    input reset,

    // VRAM Port
    input clk,
    input [31: 0] mem_addr_shared,
    input [31: 0] mem_wdata_shared,
    input [ 3: 0] mem_wmask_shared,
    output [31: 0] vram_dout0,
    input soc_vram_sel,

    // SVGA Signals
    input video_clk,
    output horizontal_sync,
    output vertical_sync,
    output enable,
    output [ 3: 0] paint_r,
    output [ 3: 0] paint_g,
    output [ 3: 0] paint_b
);

    logic signed [10:0] screen_x; // -1024/1023
    logic signed [10:0] screen_y; // -1024/1023

    logic frame;

    svga_gen svga_gen (
        .reset,
        .video_clk,  // 40 MHz for SVGA

        .screen_x,  // -1024/1023
        .screen_y,  // -1024/1023

        .horizontal_enable(),
        .vertical_enable(),
        .enable,

        .horizontal_pulse(),
        .vertical_pulse(),

        .horizontal_sync,
        .vertical_sync,

        .frame
    );

    // The current address in the framebuffer
    logic [12:0] fb_addr_read;

    // This is needed if we don't read from bram
    logic [12:0] fb_addr_read_delayed;

    // TODO prescaler determine actual screen size
    // make configurable?

    // WIDTH = 100
    // HEIGHT = 75
    logic [2:0] prescaler_x;
    logic [2:0] prescaler_y;

    logic [12:0] fb_addr_stored;
    logic read_fb;

    localparam LAT = 3;  // read_fb+1, BRAM+1, color+1

    always_ff @(posedge video_clk) begin
        if (reset || frame) begin  // reset address at start of frame
            fb_addr_read         <= FRAME_BUFFER_START;
            fb_addr_stored       <= FRAME_BUFFER_START;
            fb_addr_read_delayed <= FRAME_BUFFER_START;
            prescaler_x          <= '0;
            prescaler_y          <= '0;
            read_fb              <= '0;
        end else begin
            read_fb <= (screen_y >= 0 && screen_y < (600) && screen_x >= -LAT && screen_x < (800)-LAT);
            fb_addr_read_delayed <= fb_addr_read;

            // Inside painting area
            if (read_fb) begin
                prescaler_x <= prescaler_x + 1;

                // Reached end of pixel horizontally
                if (&prescaler_x) begin

                    // Reached end of line
                    if (screen_x == 800 - LAT) begin
                        prescaler_y <= prescaler_y + 1;

                        // Reached end of pixel vertically, store new line address
                        if (&prescaler_y) begin
                            fb_addr_stored <= fb_addr_read + 1;
                            fb_addr_read   <= fb_addr_read + 1;
                            // If not end of pixel, restore line address
                        end else begin
                            fb_addr_read <= fb_addr_stored;
                        end
                        // Else just incrment the address
                    end else begin
                        fb_addr_read <= fb_addr_read + 1;
                    end
                end
            end
        end
    end

    logic [31:0] vram_dout1;

    sram #(
        .ADDR_WIDTH(11),
        .INIT_F("images/kathi.hex")
    ) vram (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),	// User area 1 1.8V supply
        .vssd1(vssd1),	// User area 1 digital ground
`endif
    
        // Port 0: RW
        .clk0  (clk),
        .csb0  (1'b0),
        .web0  (!(|mem_wmask_shared && soc_vram_sel)),
        .wmask0(mem_wmask_shared),
        .addr0 (mem_addr_shared >> 2),
        .din0  (mem_wdata_shared),
        .dout0 (vram_dout0),

        // Port 1: R
        .clk1 (video_clk),
        .csb1 (1'b0),
        .addr1(fb_addr_read >> 2),
        .dout1(vram_dout1)
    );

    logic [7:0] color;

    // TODO palettes
    always_ff @(posedge video_clk) begin
        case (fb_addr_read_delayed[1:0])
            2'b00: color <= vram_dout1[ 7: 0];
            2'b01: color <= vram_dout1[15: 8];
            2'b10: color <= vram_dout1[23:16];
            2'b11: color <= vram_dout1[31:24];
        endcase
    end

    assign paint_r = enable ? {color[2:0], color[0]} : 4'b0000;
    assign paint_g = enable ? {color[5:3], color[3]} : 4'b0000;
    assign paint_b = enable ? {color[7:6], color[6], color[6]} : 4'b0000;


endmodule
