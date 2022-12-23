// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module simple_soc_svga #(
    parameter int FREQUENCY = 12_000_000,
    parameter int BAUDRATE  = 9600
) (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
    input clk_in,
    input reset,

    input        uart_rx,
    output logic uart_tx,

    output logic blink,

    // PMOD DVI
    output logic       dvi_clk,    // DVI pixel clock
    output logic       dvi_hsync,  // DVI horizontal sync
    output logic       dvi_vsync,  // DVI vertical sync
    output logic       dvi_de,     // DVI data enable
    output logic [3:0] dvi_r,      // 4-bit DVI red
    output logic [3:0] dvi_g,      // 4-bit DVI green
    output logic [3:0] dvi_b       // 4-bit DVI blue
);

    // * Given input frequency:        12.000 MHz
    // * Requested output frequency:   40.000 MHz
    // * Achieved output frequency:    39.750 MHz

    logic video_clk;
    logic clk;
    logic locked;

`ifdef SYNTHESIS
    SB_PLL40_2_PAD #(
        .FEEDBACK_PATH("SIMPLE"),
        .DIVR         (4'b0000),     // DIVR =  0
        .DIVF         (7'b0110100),  // DIVF = 52
        .DIVQ         (3'b100),      // DIVQ =  4
        .FILTER_RANGE (3'b001)       // FILTER_RANGE = 1
    ) uut (
        .LOCK  (locked),
        .RESETB(1'b1),
        .BYPASS(1'b0),

        .PACKAGEPIN(clk_in),
        .PLLOUTGLOBALA(clk),  // buffered input clock
        .PLLOUTGLOBALB(video_clk)  // synthesized clock
    );
`else
    assign video_clk = clk_in;
    assign clk = clk_in;
    assign locked = 1'b1;
`endif

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

    logic [31: 0] mem_addr;
    logic [31: 0] mem_wdata;
    logic [ 3: 0] mem_wmask;
    logic [31: 0] mem_rdata;
    logic         mem_rstrb;
    logic         mem_rbusy;
    logic         mem_wbusy;

    leorv32 #(
        .RESET_ADDR(32'h00000000),
        .ADDR_WIDTH(32)  // TODO 24
    ) leorv32 (
        .clk(clk),
        .reset(reset),

        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
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
            mem_arbiter <= !mem_arbiter;
        end
    end

    logic [31: 0] mem_addr_shared;
    logic [31: 0] mem_wdata_shared;
    logic [ 3: 0] mem_wmask_shared;
    logic         mem_rstrb_shared;

    assign mem_addr_shared  = mem_arbiter ? 'x : mem_addr;
    assign mem_wdata_shared = mem_arbiter ? 'x : mem_wdata;
    assign mem_wmask_shared = mem_arbiter ? 'x : mem_wmask;
    assign mem_rstrb_shared = mem_arbiter ? 'x : mem_rstrb;

    logic [31:0] mem_addr_shared_delayed;

    always_ff @(posedge clk) begin
        if (reset) begin
            mem_addr_shared_delayed <= 'b0;
        end else begin
            mem_addr_shared_delayed <= mem_addr_shared;
        end
    end

    // Memory

    localparam MEMORY_WIDTH = 10;  // 1024 words
    wire [MEMORY_WIDTH-1:0] ram_word_address = mem_addr_shared[MEMORY_WIDTH-1+2:2];
    logic [31:0] memory[0:(2**MEMORY_WIDTH)-1];

    initial begin
        $readmemh("firmware/firmware.hex", memory);
    end

    logic [31:0] mem_rdata_memory;

    always_ff @(posedge clk) begin
        if (mem_wmask_shared[0] && mem_addr_shared[31:16] == 16'h0000)
            memory[ram_word_address][7:0] <= mem_wdata_shared[7:0];
        if (mem_wmask_shared[1] && mem_addr_shared[31:16] == 16'h0000)
            memory[ram_word_address][15:8] <= mem_wdata_shared[15:8];
        if (mem_wmask_shared[2] && mem_addr_shared[31:16] == 16'h0000)
            memory[ram_word_address][23:16] <= mem_wdata_shared[23:16];
        if (mem_wmask_shared[3] && mem_addr_shared[31:16] == 16'h0000)
            memory[ram_word_address][31:24] <= mem_wdata_shared[31:24];
        if (mem_rstrb_shared) mem_rdata_memory <= memory[ram_word_address];
    end

    always_comb begin
        if (mem_addr_shared_delayed[31:16] == 16'hDEAD) begin
            mem_rdata = vram_dout0;
        end else if (mem_addr_shared_delayed == 32'h0000BEEF) begin
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
        else if (mem_addr_shared == 32'h0000BEEF && mem_rstrb) rx_flag <= 1'b0;

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

    // *** SVGA ***

    logic [3:0] paint_r, paint_g, paint_b;
    logic horizontal_sync, vertical_sync, enable;
    logic [31: 0] vram_dout0;

    svga_gen_top svga_gen_top (
        .reset,

        // VRAM Port
        .clk,
        .mem_addr_shared,
        .mem_wdata_shared,
        .mem_wmask_shared,
        .vram_dout0,

        // SVGA Signals
        .video_clk,
        .horizontal_sync,
        .vertical_sync,
        .enable,
        .paint_r,
        .paint_g,
        .paint_b
    );

`ifdef SYNTHESIS

    // DVI Pmod output
    SB_IO #(
        .PIN_TYPE(6'b010100)  // PIN_OUTPUT_REGISTERED
    ) dvi_signal_io[14:0] (
        .PACKAGE_PIN({dvi_hsync, dvi_vsync, dvi_de, dvi_r, dvi_g, dvi_b}),
        .OUTPUT_CLK(video_clk),
        .D_OUT_0({horizontal_sync, vertical_sync, enable, paint_r, paint_g, paint_b}),
        .D_OUT_1()
    );

    // DVI Pmod clock output: 180° out of phase with other DVI signals
    SB_IO #(
        .PIN_TYPE(6'b010000)  // PIN_OUTPUT_DDR
    ) dvi_clk_io (
        .PACKAGE_PIN(dvi_clk),
        .OUTPUT_CLK(video_clk),
        .D_OUT_0(1'b0),
        .D_OUT_1(1'b1)
    );

`endif

endmodule
