// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

module my_uart_rx_tb ();
    timeunit 1ns;
    timeprecision 1ps;

    parameter int FREQUENCY = 1_000_000;
    parameter int BAUDRATE = 9600;
    parameter int BAUDRATE_WAIT = 1.0 / BAUDRATE * 1e9;

    logic clk;
    logic rst;

    initial begin
        $dumpfile("uart_rx.vcd");
        $dumpvars(0, my_uart_rx_tb);
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

    logic rx;
    logic [7:0] data;
    logic valid;

    my_uart_rx #(
        .FREQUENCY(FREQUENCY),
        .BAUDRATE (BAUDRATE)
    ) my_uart_rx (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data(data),
        .valid(valid)
    );

    task automatic send_byte_ser(input bit [7:0] data);
        $display("sending: %h ", data);

        // Start bit
        rx = 0;
        #BAUDRATE_WAIT;

        // Send data LSB first
        for (int i = 0; i < 8; i++) begin
            rx = data[i];
            #BAUDRATE_WAIT;
        end

        // Stop bit
        rx = 1;
        #BAUDRATE_WAIT;
    endtask

    bit [7:0] random_value;

    initial begin
        rx = 1;

        for (int i = 0; i < 10; i++) begin
            #BAUDRATE_WAIT;
            random_value = $urandom_range(0, 255);
            send_byte_ser(random_value);
            assert (random_value == data)
            else $display("%h != %h", random_value, data);
        end

        $finish;
    end
endmodule
