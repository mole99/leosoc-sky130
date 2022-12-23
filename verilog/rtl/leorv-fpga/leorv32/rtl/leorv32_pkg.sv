// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

package leorv32_pkg;

    // Opcodes
    parameter bit [6:0] OP_IMM      = 7'b0010011;
    parameter bit [6:0] OP_LUI      = 7'b0110111;
    parameter bit [6:0] OP_AUIPC    = 7'b0010111;
    parameter bit [6:0] OP_ARITH    = 7'b0110011;
    parameter bit [6:0] OP_JAL      = 7'b1101111;
    parameter bit [6:0] OP_JALR     = 7'b1100111;
    parameter bit [6:0] OP_BRANCH   = 7'b1100011;
    parameter bit [6:0] OP_LOAD     = 7'b0000011;
    parameter bit [6:0] OP_STORE    = 7'b0100011;
    parameter bit [6:0] OP_MISC_MEM = 7'b0001111;
    parameter bit [6:0] OP_SYSTEM   = 7'b1110011;
    
    // Functions for OP_IMM
    parameter bit [2:0] FUNC_ADDI   = 3'b000;
    parameter bit [2:0] FUNC_SLTI   = 3'b010;
    parameter bit [2:0] FUNC_SLTIU  = 3'b011;
    parameter bit [2:0] FUNC_ANDI   = 3'b111;
    parameter bit [2:0] FUNC_ORI    = 3'b110;
    parameter bit [2:0] FUNC_XORI   = 3'b100;
    parameter bit [2:0] FUNC_SLLI       = 3'b001;
    parameter bit [2:0] FUNC_SRLI_SRAI  = 3'b101;
    
    // Functions for OP_ARITH
    parameter bit [2:0] FUNC_ADD_SUB    = 3'b000;
    parameter bit [2:0] FUNC_SLT        = 3'b010;
    parameter bit [2:0] FUNC_SLTU       = 3'b011;
    parameter bit [2:0] FUNC_AND        = 3'b111;
    parameter bit [2:0] FUNC_OR         = 3'b110;
    parameter bit [2:0] FUNC_XOR        = 3'b100;
    parameter bit [2:0] FUNC_SLL        = 3'b001;
    parameter bit [2:0] FUNC_SRL_SRA    = 3'b101;
    
    // Functions for OP_BRANCH
    parameter bit [2:0] FUNC_BEQ    = 3'b000;
    parameter bit [2:0] FUNC_BNE    = 3'b001;
    parameter bit [2:0] FUNC_BLT    = 3'b100;
    parameter bit [2:0] FUNC_BLTU   = 3'b110;
    parameter bit [2:0] FUNC_BGE    = 3'b101;
    parameter bit [2:0] FUNC_BGEU   = 3'b111;
    
    // Functions for OP_STORE
    parameter bit [2:0] FUNC_SB  = 3'b000;
    parameter bit [2:0] FUNC_SH  = 3'b001;
    parameter bit [2:0] FUNC_SW  = 3'b010;
    
    // Functions for OP_LOAD
    parameter bit [2:0] FUNC_LB  = 3'b000;
    parameter bit [2:0] FUNC_LH  = 3'b001;
    parameter bit [2:0] FUNC_LW  = 3'b010;
    parameter bit [2:0] FUNC_LBU = 3'b100;
    parameter bit [2:0] FUNC_LHU = 3'b101;

    
    // Functions for OP_SYSTEM
    parameter bit [2:0] FUNC_CSRRW  = 3'b001;
    parameter bit [2:0] FUNC_CSRRS  = 3'b010;
    parameter bit [2:0] FUNC_CSRRC  = 3'b011;
    parameter bit [2:0] FUNC_CSRRWI = 3'b101;
    parameter bit [2:0] FUNC_CSRRSI = 3'b110;
    parameter bit [2:0] FUNC_CSRRCI = 3'b111;
    
    // CSRs
    parameter bit [11:0] CSR_RDCYCLE     = 12'hC00;
    parameter bit [11:0] CSR_RDCYCLEH    = 12'hC80;
    parameter bit [11:0] CSR_RDTIME      = 12'hC01;
    parameter bit [11:0] CSR_RDTIMEH     = 12'hC81;
    parameter bit [11:0] CSR_RDINSTRET   = 12'hC02;
    parameter bit [11:0] CSR_RDINSTRETH  = 12'hC82;
    parameter bit [11:0] CSR_MHARTID     = 12'hF14;

endpackage
