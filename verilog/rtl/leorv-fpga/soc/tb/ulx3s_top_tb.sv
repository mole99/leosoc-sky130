// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1 ns / 1 ps

module ulx3s_top_tb;

    parameter int CLOCK_PERIOD_NS = 40;  // 25 MHz clock

    initial begin
        $dumpfile("ulx3s_top_tb.fst");
        $dumpvars(0, ulx3s_top_tb);
        for (int i = 0; i < 32; i++) $dumpvars(0, ulx3s_top.simple_soc.leorv32.regs[i]);
    end

    logic [7:0] leds;

    logic ser_tx;
    logic ser_rx;

    logic [6:0] buttons;

    logic clk = 0;
    always #(CLOCK_PERIOD_NS / 2) clk = !clk;

    logic resetn;

    assign buttons[0]   = resetn;
    assign buttons[6:1] = '1;

    initial begin
        resetn = 1'b0;
        ser_rx = 1'b1;

        $display("Starting simulation.");

        #(CLOCK_PERIOD_NS * 2);
        resetn = 1'b1;
        #(CLOCK_PERIOD_NS * 3000);

        $display("Completed simulation.");
        $finish;
    end

    ulx3s_top ulx3s_top (
        .clk_25mhz(clk),

        .ftdi_rxd(ser_tx),
        .ftdi_txd(ser_rx),

        .btn(buttons),

        .led(leds)
    );

endmodule
