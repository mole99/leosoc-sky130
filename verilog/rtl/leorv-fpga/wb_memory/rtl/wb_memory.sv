// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module wb_memory #(
    parameter NUM_WMASKS = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 11
) (

    // Wishbone port
    input         io_wbs_clk,
    input         io_wbs_rst,
    input  [31:0] io_wbs_adr,
    input  [31:0] io_wbs_datwr,
    output [31:0] io_wbs_datrd,
    input         io_wbs_we,
    input  [ 3:0] io_wbs_sel,
    input         io_wbs_stb,
    output logic  io_wbs_ack,
    input         io_wbs_cyc,

    // Memory Port
    output logic web,
    output [NUM_WMASKS-1:0] wmask,
    output [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] din,
    input  [DATA_WIDTH-1:0] dout

);

    // Assign address, ignore two lowest bits
    assign addr = io_wbs_adr[ADDR_WIDTH+1:2];
    assign wmask = io_wbs_sel;
    assign din = io_wbs_datwr;
    assign io_wbs_datrd = dout;

    always_ff @(posedge io_wbs_clk, posedge io_wbs_rst) begin
        if (io_wbs_rst) begin
            web <= 1'b1;
            io_wbs_ack <= 1'b0;
        end else begin
            web <= 1'b1;
            io_wbs_ack <= 1'b0;
            
            // Write operation, ack immediately
            if (io_wbs_cyc && io_wbs_stb && !io_wbs_ack && io_wbs_we) begin
                web <= 1'b0;
                io_wbs_ack <= 1'b1;
            end
            
            // Read operation, ack immediately
            if (io_wbs_cyc && io_wbs_stb && !io_wbs_ack && !io_wbs_we) begin
                io_wbs_ack <= 1'b1;
            end
        end
    end

endmodule
