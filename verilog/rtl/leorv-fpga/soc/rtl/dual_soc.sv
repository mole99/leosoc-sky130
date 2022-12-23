// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module dual_soc #(
    parameter int FREQUENCY = 12_000_000,
    parameter int BAUDRATE  = 9600
) (
    input clk,
    input reset,

    input        uart_rx,
    output logic uart_tx,

    output logic blink
);

    // Synchronization

    logic uart_rx_sync;

    synchronizer #(
        .FF_COUNT(3)
    ) synchronizer (
        .clk(clk),
        .resetn(!reset),
        .in(uart_rx),

        .out(uart_rx_sync)
    );

    // CPU

    logic [31: 0] mem_addr_core0;
    logic [31: 0] mem_wdata_core0;
    logic [ 3: 0] mem_wmask_core0;
    logic         mem_rstrb_core0;

    logic [31: 0] mem_addr_core1;
    logic [31: 0] mem_wdata_core1;
    logic [ 3: 0] mem_wmask_core1;
    logic         mem_rstrb_core1;

    logic [31: 0] mem_rdata;
    logic         mem_rbusy;
    logic         mem_wbusy;



    leorv32 #(
        .RESET_ADDR(32'h00000000),
        .ADDR_WIDTH(16),
        .MHARTID(0)
    ) leorv32_core0 (
        .clk(clk),
        .reset(reset),

        .mem_addr (mem_addr_core0),
        .mem_wdata(mem_wdata_core0),
        .mem_wmask(mem_wmask_core0),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb_core0),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        
        .mhartid_0(1'b0)
    );

    logic reset_delayed;
    always_ff @(posedge clk) begin
        if (reset) begin
            reset_delayed <= 1'b1;
        end else begin
            reset_delayed <= reset;
        end
    end

    leorv32 #(
        .RESET_ADDR(32'h00000000),
        .ADDR_WIDTH(16),
        .MHARTID(1)
    ) leorv32_core1 (
        .clk(clk),
        .reset(reset_delayed),

        .mem_addr (mem_addr_core1),
        .mem_wdata(mem_wdata_core1),
        .mem_wmask(mem_wmask_core1),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb_core1),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        
        .mhartid_0(1'b0)
    );

    // Bus arbitration

    logic mem_arbiter;

    always_ff @(posedge clk) begin
        if (reset) begin
            mem_arbiter <= 1'b0;
        end else begin
            mem_arbiter = !mem_arbiter;
        end
    end

    logic [31: 0] mem_addr_shared;
    logic [31: 0] mem_wdata_shared;
    logic [ 3: 0] mem_wmask_shared;
    logic         mem_rstrb_shared;

    assign mem_addr_shared  = mem_arbiter ? mem_addr_core1 : mem_addr_core0;
    assign mem_wdata_shared = mem_arbiter ? mem_wdata_core1 : mem_wdata_core0;
    assign mem_wmask_shared = mem_arbiter ? mem_wmask_core1 : mem_wmask_core0;
    assign mem_rstrb_shared = mem_arbiter ? mem_rstrb_core1 : mem_rstrb_core0;

    logic [31:0] mem_addr_shared_delayed;

    always_ff @(posedge clk) begin
        if (reset) begin
            mem_addr_shared_delayed <= 1'b0;
        end else begin
            mem_addr_shared_delayed <= mem_addr_shared;
        end
    end

    // Memory

    localparam MEMORY_WIDTH = 11;  // 2048 words
    wire [MEMORY_WIDTH-3:0] ram_word_address = mem_addr_shared[MEMORY_WIDTH-1:2];
    logic [31:0] memory[0:(2**MEMORY_WIDTH)-1];

    initial begin
        $readmemh("firmware/firmware.hex", memory);
    end

    logic [31:0] mem_rdata_memory;

    always_ff @(posedge clk) begin
        if (mem_wmask_shared[0]) memory[ram_word_address][7:0] <= mem_wdata_shared[7:0];
        if (mem_wmask_shared[1]) memory[ram_word_address][15:8] <= mem_wdata_shared[15:8];
        if (mem_wmask_shared[2]) memory[ram_word_address][23:16] <= mem_wdata_shared[23:16];
        if (mem_wmask_shared[3]) memory[ram_word_address][31:24] <= mem_wdata_shared[31:24];
        if (mem_rstrb_shared) mem_rdata_memory <= memory[ram_word_address];
    end

    always_comb begin
        if (mem_addr_shared_delayed == 16'hBEEF) begin
            mem_rdata = uart_reg;
        end else begin
            mem_rdata = mem_rdata_memory;
        end
    end

    assign mem_wbusy = 1'b0;
    assign mem_rbusy = 1'b0;

    // Blinky

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            blink <= 1'b0;
        end else if (mem_addr_shared == 32'h0000FFFF && (|mem_wmask_shared)) begin
            blink = mem_wdata_shared[0];
        end
    end

    // Uart

    logic mem_rstrb_delayed;
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_rstrb_delayed <= 1'b0;
        end else begin
            mem_rstrb_delayed <= mem_rstrb_shared;
        end
    end

    logic rx_flag;
    logic [31: 0] uart_reg;
    always_ff @(posedge clk) begin
        if (reset) begin
            rx_flag  <= 1'b0;
            uart_reg <= '0;
        end else if (!rx_done_delayed && rx_done) rx_flag <= 1'b1;
        else if (mem_addr_shared == 16'hBEEF && mem_rstrb_shared) rx_flag <= 1'b0;

        uart_reg <= {rx_flag, tx_busy, {22{1'b0}}, rx_received};
    end

    logic [7:0] rx_received;
    logic rx_done;
    logic rx_done_delayed;

    always_ff @(posedge clk) begin
        if (reset) begin
            rx_done_delayed <= 1'b0;
        end else begin
            rx_done_delayed <= rx_done;
        end
    end

    my_uart_rx #(
        .FREQUENCY(FREQUENCY),
        .BAUDRATE (BAUDRATE)
    ) my_uart_rx (
        .clk(clk),
        .rst(reset),
        .rx(uart_rx_sync),
        .data(rx_received),
        .valid(rx_done)
    );

    logic tx_busy;

    my_uart_tx #(
        .FREQUENCY(FREQUENCY),
        .BAUDRATE (BAUDRATE)
    ) my_uart_tx (
        .clk(clk),
        .rst(reset),
        .data(mem_wdata_shared[7:0]),
        .start(mem_addr_shared == 16'hBEEF && (|mem_wmask_shared)),
        .tx(uart_tx),
        .busy(tx_busy)
    );

endmodule
