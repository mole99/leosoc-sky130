// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1 ns / 1 ps

module icebreaker_top_tb;

    parameter int CLOCK_PERIOD_NS = 83;  // 12 MHz clock
    parameter int SER_BIT_PERIOD_NS = 104167;

    initial begin
        $dumpfile("icebreaker_top_tb.fst");
        $dumpvars(0, icebreaker_top_tb);
        for (int i = 0; i < 32; i++) $dumpvars(0, icebreaker_top.simple_soc_svga.leorv32.regs[i]);
        //for (int i=0;i<32;i++) $dumpvars(0, icebreaker_top.simple_soc_svga.leorv32_core1.regs[i]);
    end

    logic led_r;
    logic led_g;

    logic ser_tx;
    logic ser_rx;

    logic button_run;
    logic button_step;
    logic button_stop;

    logic clk = 0;
    always #(CLOCK_PERIOD_NS / 2) clk = !clk;

    logic resetn;

    initial begin
        resetn = 0;
        button_run = 0;
        button_step = 0;
        button_stop = 0;
        ser_rx = 1;

        $display("Starting simulation.");

        #(CLOCK_PERIOD_NS * 2);
        resetn = 1;
        button_run = 1;

        #(CLOCK_PERIOD_NS * 300);
        send_byte_ser("!");
        #(CLOCK_PERIOD_NS * 60000);

        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);
        #(CLOCK_PERIOD_NS * 60000);


        $display("Completed simulation.");
        $finish;
    end

    icebreaker_top icebreaker_top (
        .CLK(clk),

        .TX(ser_tx),
        .RX(ser_rx),

        .BTN1(button_run),
        .BTN2(button_step),
        .BTN3(button_stop),

        .LEDR_N(led_r),
        .LEDG_N(led_g),
        .BTN_N (resetn)
    );

    logic [7:0] recv_byte = 0;

    always @(negedge ser_tx) begin
        read_byte_ser;
    end

    task automatic read_byte_ser;
        #(SER_BIT_PERIOD_NS / 2);  // Wait half baud
        if ((ser_tx == 0)) begin

            #SER_BIT_PERIOD_NS;

            // Read data LSB first
            for (int j = 0; j < 8; j++) begin
                recv_byte[j] = ser_tx;
                #SER_BIT_PERIOD_NS;
            end

            if ((ser_tx == 1)) begin

                //$write(colors::Green);
                $display("leorv32 --> uart: 0x%h '%c'", recv_byte, recv_byte);
                //$write(colors::None);
            end
        end
    endtask

    task automatic send_byte_ser(input bit [7:0] data);
        //$write(colors::Blue);
        $display("uart --> leorv32: 0x%h '%c'", data, data);
        //$write(colors::None);

        // Start bit
        ser_rx = 0;
        #SER_BIT_PERIOD_NS;

        // Send data LSB first
        for (int i = 0; i < 8; i++) begin
            ser_rx = data[i];
            #SER_BIT_PERIOD_NS;
        end

        // Stop bit
        ser_rx = 1;
        #SER_BIT_PERIOD_NS;
    endtask

endmodule
