// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

module my_uart_tx_tb ();
    timeunit 1ns;
    timeprecision 1ps;
    
    parameter int FREQUENCY = 1_000_000;
    parameter int BAUDRATE = 9600;
    parameter int BAUDRATE_WAIT = 1.0 / BAUDRATE * 1e9;

    logic clk;
    logic rst;

    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, my_uart_tx_tb);
    end

    initial begin
        clk <= 0;
        rst <= 1;
        #10;
        rst <= 0;
    end

    always begin
        #(1.0 / FREQUENCY / 2 * 1e9);
        clk <= ~clk;
    end

    logic tx;
    logic [7:0] data;
    logic start;
    logic busy;

    my_uart_tx #(
        .FREQUENCY(FREQUENCY),
        .BAUDRATE (BAUDRATE)
    ) my_uart_tx (
        .clk(clk),
        .rst(rst),
        .data(data),
        .start(start),
        .tx(tx),
        .busy(busy)
    );

    logic [7:0] recv_byte = 0;

    always @(negedge tx) begin
        read_byte_ser;
    end

    bit [7:0] random_value;

    initial begin
        start = 0;
        data  = 0;
        for (int i = 0; i < 10; i++) begin
            #BAUDRATE_WAIT;
            random_value = $urandom_range(0, 255);
            data = random_value;
            start = 1;
            #(1.0 / FREQUENCY * 1e9);
            start = 0;
            @(negedge busy);
            assert (random_value == recv_byte)
            else $display("%h != %h", random_value, recv_byte);
        end
        $finish;
    end

    initial begin
        #(BAUDRATE_WAIT * 12 * 10);
        $display("Error: timeout");
        $error;
    end

    task automatic read_byte_ser;
        #(BAUDRATE_WAIT / 2);  // Wait half baud
        if ((tx == 0)) begin

            #BAUDRATE_WAIT;

            // Read data LSB first
            for (int j = 0; j < 8; j++) begin
                recv_byte[j] = tx;
                #BAUDRATE_WAIT;
            end

            if ((tx == 1)) begin
                $display("received: %h", recv_byte);
            end
        end
    endtask

endmodule
