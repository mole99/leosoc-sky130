// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module icebreaker_top (
    input CLK,

    // On-board
    input RX,
    output logic TX,

    input BTN_N,
    output logic LEDR_N,
    output logic LEDG_N,

    // PMOD 2
    input BTN1,
    input BTN2,
    input BTN3,

    // PMOD DVI
    output logic       dvi_clk,    // DVI pixel clock
    output logic       dvi_hsync,  // DVI horizontal sync
    output logic       dvi_vsync,  // DVI vertical sync
    output logic       dvi_de,     // DVI data enable
    output logic [3:0] dvi_r,      // 4-bit DVI red
    output logic [3:0] dvi_g,      // 4-bit DVI green
    output logic [3:0] dvi_b       // 4-bit DVI blue
);

    localparam int FREQUENCY = 12_000_000;
    localparam int BAUDRATE = 9600;

    logic reset;

    SB_GB reset_buffer (
        .USER_SIGNAL_TO_GLOBAL_BUFFER(!BTN_N),
        .GLOBAL_BUFFER_OUTPUT(reset)
    );

    simple_soc_svga #(
        .FREQUENCY(FREQUENCY),
        .BAUDRATE (BAUDRATE)
    ) simple_soc_svga (
        .clk_in(CLK),
        .reset (reset),

        .uart_rx(RX),
        .uart_tx(TX),

        .blink(LEDG_N),

        .dvi_clk  (dvi_clk),    // DVI pixel clock
        .dvi_hsync(dvi_hsync),  // DVI horizontal sync
        .dvi_vsync(dvi_vsync),  // DVI vertical sync
        .dvi_de   (dvi_de),     // DVI data enable
        .dvi_r    (dvi_r),      // 4-bit DVI red
        .dvi_g    (dvi_g),      // 4-bit DVI green
        .dvi_b    (dvi_b)       // 4-bit DVI blue
    );

    assign LEDR_N = 1'b0;

endmodule
