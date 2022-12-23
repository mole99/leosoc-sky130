// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module mem_port_switch #(
    parameter NUM_WMASKS = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 11
) (
    input port_select,

    // Input Memory Port 0 - R/W
    input  input_web0,
    input  [NUM_WMASKS-1:0] input_wmask0,
    input  [ADDR_WIDTH-1:0] input_addr0,
    input  [DATA_WIDTH-1:0] input_din0,
    output [DATA_WIDTH-1:0] input_dout0,
    
    // Input Memory Port 1 - R/W
    input  input_web1,
    input  [NUM_WMASKS-1:0] input_wmask1,
    input  [ADDR_WIDTH-1:0] input_addr1,
    input  [DATA_WIDTH-1:0] input_din1,
    output [DATA_WIDTH-1:0] input_dout1,
    
    // Output Memory Port 0 - R/W
    output output_web0,
    output [NUM_WMASKS-1:0] output_wmask0,
    output [ADDR_WIDTH-1:0] output_addr0,
    output [DATA_WIDTH-1:0] output_din0,
    input  [DATA_WIDTH-1:0] output_dout0,
    
    // Output Memory Port 1 - R
    output [ADDR_WIDTH-1:0] output_addr1,
    input  [DATA_WIDTH-1:0] output_dout1
);

    // port_select == 0 -> Input Memory Port 0 goes to Output Memory Port 0
    // port_select == 0 -> Input Memory Port 1 goes to Output Memory Port 1
    
    // port_select == 1 -> Input Memory Port 0 goes to Output Memory Port 1
    // port_select == 1 -> Input Memory Port 1 goes to Output Memory Port 0


    assign output_web0   = !port_select ? input_web0   : input_web1;
    assign output_wmask0 = !port_select ? input_wmask0 : input_wmask1;
    assign output_addr0  = !port_select ? input_addr0  : input_addr1;
    assign output_din0   = !port_select ? input_din0   : input_din1;
    
    assign output_addr1  = !port_select ? input_addr1  : input_addr0;
    
    assign input_dout0   = !port_select ? output_dout0 : output_dout1;
    assign input_dout1   = !port_select ? output_dout1 : output_dout0;

endmodule
