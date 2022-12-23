// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module soc #(
    parameter int FREQUENCY = 40_000_000,
    parameter int BAUDRATE  = 9600
) (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
    input clk, // 40 MHz
    input reset,

    input        uart_rx,
    output logic uart_tx,

    output logic blink,

    // PMOD DVI TODO
    output       dvi_clk,    // DVI pixel clock
    output       dvi_hsync,  // DVI horizontal sync
    output       dvi_vsync,  // DVI vertical sync
    output       dvi_de,     // DVI data enable
    output [3:0] dvi_r,      // 4-bit DVI red
    output [3:0] dvi_g,      // 4-bit DVI green
    output [3:0] dvi_b,      // 4-bit DVI blue
    
    // Wishbone Port
    
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,
    
    input port_select
);

    logic video_clk;
    assign video_clk = clk;

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

    // Configuration

    localparam SOC_ADDRW = 24;
    
    localparam NUM_WMASKS = 4;
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 11;
    
    localparam WRAM_MASK = 8'h00;
    localparam VRAM_MASK = 8'h01;
    localparam UART_MASK = 8'h0A;
    localparam BLINK_MASK = 8'h0F;
    
    logic soc_wram_sel;
    logic soc_vram_sel;
    logic soc_uart_sel;
    logic soc_blink_sel;
    
    assign soc_wram_sel = mem_addr_shared[23:16] == WRAM_MASK;
    assign soc_vram_sel = mem_addr_shared[23:16] == VRAM_MASK;
    assign soc_uart_sel = mem_addr_shared[23:16] == UART_MASK;
    assign soc_blink_sel = mem_addr_shared[23:16] == BLINK_MASK;
    
    logic soc_wram_sel_del;
    logic soc_vram_sel_del;
    logic soc_uart_sel_del;
    logic soc_blink_sel_del;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            soc_wram_sel_del <= 1'b0;
            soc_vram_sel_del <= 1'b0;
            soc_uart_sel_del <= 1'b0;
            soc_blink_sel_del <= 1'b0;
        end else begin
            soc_wram_sel_del <= soc_wram_sel;
            soc_vram_sel_del <= soc_vram_sel;
            soc_uart_sel_del <= soc_uart_sel;
            soc_blink_sel_del <= soc_blink_sel;
        end
    end
    
    

    logic [SOC_ADDRW-1: 0] mem_addr_core0;
    logic [31: 0] mem_wdata_core0;
    logic [ 3: 0] mem_wmask_core0;
    logic         mem_rstrb_core0;

    logic [SOC_ADDRW-1: 0] mem_addr_core1;
    logic [31: 0] mem_wdata_core1;
    logic [ 3: 0] mem_wmask_core1;
    logic         mem_rstrb_core1;

    logic [31: 0] mem_rdata;
    logic         mem_rbusy;
    logic         mem_wbusy;

    // Peripherals have no latency
    assign mem_wbusy = 1'b0;
    assign mem_rbusy = 1'b0;

    // CPU

    leorv32 leorv32_core0 (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),	// User area 1 1.8V power
        .vssd1(vssd1),	// User area 1 digital ground
`endif
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

    leorv32 leorv32_core1 (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),	// User area 1 1.8V power
        .vssd1(vssd1),	// User area 1 digital ground
`endif
        .clk(1'b0), // TODO core1 is deactivated because of interference, investigate
        .reset(reset_delayed),

        .mem_addr (mem_addr_core1),
        .mem_wdata(mem_wdata_core1),
        .mem_wmask(mem_wmask_core1),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb_core1),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        
        .mhartid_0(1'b1)
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

    logic [SOC_ADDRW-1: 0] mem_addr_shared;
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
    
    // Wishbone Memory Module
    
    logic wb_web;
    logic [NUM_WMASKS-1:0] wb_wmask;
    logic [ADDR_WIDTH-1:0] wb_addr;
    logic [DATA_WIDTH-1:0] wb_din;
    logic [DATA_WIDTH-1:0] wb_dout;
    
    logic periph_select;
    assign periph_select = wbs_adr_i[31:28] == 4'h3; // From 0x30000000 to 0x3FFFFFFF
    
    wb_memory #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) wb_memory_inst (

        // Wishbone port
        .io_wbs_clk(wb_clk_i),
        .io_wbs_rst(wb_rst_i),
        .io_wbs_adr(wbs_adr_i),
        .io_wbs_datwr(wbs_dat_i),
        .io_wbs_datrd(wbs_dat_o),
        .io_wbs_we(wbs_we_i),
        .io_wbs_sel(wbs_sel_i),
        .io_wbs_stb(wbs_stb_i && periph_select),
        .io_wbs_ack(wbs_ack_o),
        .io_wbs_cyc(wbs_cyc_i && periph_select),

        // Memory Port
        .web(wb_web),
        .wmask(wb_wmask),
        .addr(wb_addr),
        .din(wb_din),
        .dout(wb_dout)
    );
    
    // Memory Port Switch
    
    mem_port_switch #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) mem_port_switch_inst (
        .port_select(port_select),

        // Input Memory Port 0 - R/W
        .input_web0(wb_web),
        .input_wmask0(wb_wmask),
        .input_addr0(wb_addr),
        .input_din0(wb_din),
        .input_dout0(wb_dout),
        
        // Input Memory Port 1 - R/W
        .input_web1(!(|mem_wmask_shared && soc_wram_sel)),
        .input_wmask1(mem_wmask_shared),
        .input_addr1(mem_addr_shared >> 2),
        .input_din1(mem_wdata_shared),
        .input_dout1(mem_rdata_memory),
        
        // Output Memory Port 0 - R/W
        .output_web0(wram_web0),
        .output_wmask0(wram_wmask0),
        .output_addr0(wram_addr0),
        .output_din0(wram_din0),
        .output_dout0(wram_dout0),
        
        // Output Memory Port 1 - R
        .output_addr1(wram_addr1),
        .output_dout1(wram_dout1)
    );

    // WRAM Memory
    
    // Memory Port 1 - R/W
    logic wram_web0;
    logic [NUM_WMASKS-1:0] wram_wmask0;
    logic [ADDR_WIDTH-1:0] wram_addr0;
    logic [DATA_WIDTH-1:0] wram_din0;
    logic [DATA_WIDTH-1:0] wram_dout0;
    
    // Memory Port 2 - R
    logic [ADDR_WIDTH-1:0] wram_addr1;
    logic [DATA_WIDTH-1:0] wram_dout1;

    logic [31:0] mem_rdata_memory;
    
    sram #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) wram (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),	// User area 1 1.8V power
        .vssd1(vssd1),	// User area 1 digital ground
`endif
    
        // Port 0: RW
        .clk0  (clk),
        .csb0  (1'b0),
        .web0  (wram_web0),
        .wmask0(wram_wmask0),
        .addr0 (wram_addr0),
        .din0  (wram_din0),
        .dout0 (wram_dout0),

        // Port 1: R
        .clk1 (clk),
        .csb1 (1'b0),
        .addr1(wram_addr1),
        .dout1(wram_dout1)
    );

    // SoC read data

    always_comb begin
        // VRAM
        if (soc_vram_sel_del) begin
            mem_rdata = vram_dout0;
        // UART
        end else if (soc_uart_sel_del) begin
            mem_rdata = uart_reg;
        // Blink
        end else if (soc_blink_sel_del) begin
            mem_rdata = {32{blink}};
        // WRAM
        end else begin
            mem_rdata = mem_rdata_memory;
        end
    end

    // Blinky

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            blink <= 1'b0;
        end else if (soc_blink_sel && (|mem_wmask_shared)) begin
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
        else if (soc_uart_sel && mem_rstrb_shared) rx_flag <= 1'b0;

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
        .start(soc_uart_sel && (|mem_wmask_shared)),
        .tx(uart_tx),
        .busy(tx_busy)
    );

    // *** SVGA ***

    logic [3:0] paint_r, paint_g, paint_b;
    logic horizontal_sync, vertical_sync, enable;
    logic [31: 0] vram_dout0;

    svga_gen_top svga_gen_top (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),	// User area 1 1.8V power
        .vssd1(vssd1),	// User area 1 digital ground
`endif
        .reset,

        // VRAM Port
        .clk,
        .mem_addr_shared,
        .mem_wdata_shared,
        .mem_wmask_shared,
        .vram_dout0,
        .soc_vram_sel,

        // SVGA Signals
        .video_clk,
        .horizontal_sync,
        .vertical_sync,
        .enable,
        .paint_r,
        .paint_g,
        .paint_b
    );

    assign dvi_hsync = horizontal_sync;
    assign dvi_vsync = vertical_sync;
    assign dvi_de = enable;
    assign dvi_r = paint_r;
    assign dvi_g = paint_g;
    assign dvi_b = paint_b;
    
    assign dvi_clk = video_clk; // TODO 180° phase

endmodule
