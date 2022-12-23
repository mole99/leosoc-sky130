// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module ulx3s_top (
    input clk_25mhz,

    input  ftdi_txd,
    output ftdi_rxd,

    input  [6:0] btn,
    output [7:0] led
);
    localparam FREQUENCY = 25_000_000;
    localparam BAUDRATE = 9600;

    simple_soc #(
        .FREQUENCY(FREQUENCY),
        .BAUDRATE (BAUDRATE)
    ) simple_soc (
        .clk  (clk_25mhz),
        .reset(!btn[0]),

        .uart_rx(ftdi_txd),
        .uart_tx(ftdi_rxd),

        .blink(led[7])
    );

endmodule
