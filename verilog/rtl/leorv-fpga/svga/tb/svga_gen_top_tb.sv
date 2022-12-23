// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns/1ps

module svga_gen_top_tb;
    
    logic reset = 1;
    
    initial begin
        $dumpfile("svga.fst");
        $dumpvars(0, svga_gen_top_tb);
        #10;
        reset = 0;
        #(4*600*800);
        $finish;
    end
    
    logic btn1, btn2, btn3;
    
    initial begin
        #10;
        btn1 = 1'b0;
        btn2 = 1'b0;
        btn3 = 1'b0;
        #10;
        //btn1 = 1'b1;
    end
    
    logic clk = 1'b0;
    
    always begin
        #1 clk = !clk;
    end
    
    logic ser_tx, ser_rx;
    logic led_r, led_g;
    
    svga_gen_top svga_gen_top (
        .CLK(clk),

        .TX(ser_tx),
        .RX(ser_rx),

        .BTN1(btn1),
        .BTN2(btn2),
        .BTN3(btn3),

        .LEDR_N(led_r),
        .LEDG_N(led_g),
        .BTN_N (!reset),

        .dvi_clk(),      // DVI pixel clock
        .dvi_hsync(),    // DVI horizontal sync
        .dvi_vsync(),    // DVI vertical sync
        .dvi_de(),       // DVI data enable
        .dvi_r(),  // 4-bit DVI red
        .dvi_g(),  // 4-bit DVI green
        .dvi_b()   // 4-bit DVI blue
    );

endmodule
