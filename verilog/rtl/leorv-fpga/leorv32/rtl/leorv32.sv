// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module leorv32_alu (
    input [31:0] input1,
    input [31:0] input2,

    output wire [31:0] result_add,
    output wire [31:0] result_subtract,

    output wire [31:0] result_and,
    output wire [31:0] result_or,
    output wire [31:0] result_xor,

    output wire result_lt,
    output wire result_ltu,
    output wire result_eq
);

    assign result_add = input1 + input2;
    assign result_subtract = input1 - input2;

    assign result_and = input1 & input2;
    assign result_or = input1 | input2;
    assign result_xor = input1 ^ input2;

    assign result_lt = $signed(input1) < $signed(input2);
    assign result_ltu = input1 < input2;
    assign result_eq = (result_subtract == 0);

endmodule

module shifter_right (
    input  [31:0] data_in,
    input  [ 4:0] shift,
    input         arith,
    output [31:0] data_out
);

    assign data_out = $signed({arith && data_in[31], data_in}) >>> shift;

endmodule

module barrel_shifter_right (
    input        [31:0] data_in,
    input        [ 4:0] shift,
    input               arith,
    output logic [31:0] data_out
);

    logic [32:0] tmp;

    always_comb begin
        tmp = {arith && data_in[31], data_in};
        if (shift[4]) tmp = $signed(tmp) >>> 16;
        if (shift[3]) tmp = $signed(tmp) >>> 8;
        if (shift[2]) tmp = $signed(tmp) >>> 4;
        if (shift[1]) tmp = $signed(tmp) >>> 2;
        if (shift[0]) tmp = $signed(tmp) >>> 1;
        data_out = tmp;
    end

endmodule


module leorv32 #(
    parameter int RESET_ADDR = 32'h00000000,
    parameter int ADDR_WIDTH = 24,
    parameter int MHARTID    = 0
) (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
    input clk,
    input reset,

    output [31:0] mem_addr,   // address
    output [31:0] mem_wdata,  // write data
    output [ 3:0] mem_wmask,  // write mask
    input  [31:0] mem_rdata,  // read data
    output        mem_rstrb,  // read strobe
    input         mem_rbusy,  // read busy
    input         mem_wbusy,  // write busy

    input mhartid_0 // ored with the last bit of MAHRTID
);
    // Registers

    logic [ADDR_WIDTH-1:0] PC;
    logic [31: 0] regs [32];

    // Instruction and subfields

    logic [31: 0] instr;
    logic [ 6: 0] opcode;
    logic [ 4: 0] rd;
    logic [ 4: 0] rs1;
    logic [ 4: 0] rs2;
    logic [ 2: 0] funct3;
    logic [ 6: 0] funct7;

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    // Sign-extended immediates

    logic [31: 0] I_type_imm;
    logic [31: 0] S_type_imm;
    logic [31: 0] B_type_imm;
    logic [31: 0] U_type_imm;
    logic [31: 0] J_type_imm;

    assign I_type_imm = {{21{instr[31]}}, instr[30:20]};
    assign S_type_imm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
    assign B_type_imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    assign U_type_imm = {instr[31:12], {12{1'b0}}};
    assign J_type_imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

    // Debug

    logic is_nop;
    assign is_nop = instr === {{12{1'b0}}, {5{1'b0}}, leorv32_pkg::FUNC_ADDI, {5{1'b0}}, leorv32_pkg::OP_IMM};

    // Memory access

    logic [31: 0] store_data;
    logic [ 3: 0] store_wmask;

    logic [ADDR_WIDTH-1: 0] store_address;
    logic [ADDR_WIDTH-1: 0] load_address;

    assign mem_wmask = store_wmask;
    assign mem_wdata = store_data;

    assign store_address = rs1_content + S_type_imm;
    assign load_address = rs1_content + I_type_imm;

    assign mem_addr  = core_state == ST_EXECUTE && opcode == leorv32_pkg::OP_LOAD  ? load_address
                     : core_state == ST_EXECUTE && opcode == leorv32_pkg::OP_STORE ? store_address
                     : PC;

    assign mem_rstrb = core_state == ST_FETCH || (core_state == ST_EXECUTE && opcode == leorv32_pkg::OP_LOAD);

    // Core state machine

    typedef enum {
        ST_FETCH,
        ST_FETCH_WAIT,
        ST_EXECUTE,
        ST_EXECUTE_WAIT
    } state_t;

    state_t core_state;

    logic [31: 0] rs1_content;
    logic [31: 0] rs2_content;

    always_ff @(posedge clk) begin
        if (reset) regs[0] <= '0;
        else if (writeBack && rd != 0) regs[rd] <= writeBackData;
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            core_state  <= ST_FETCH;
            instret     <= '0;
            PC          <= RESET_ADDR;
            instr       <= '0;
            rs1_content <= '0;
            rs2_content <= '0;
        end else begin
            case (core_state)
                ST_FETCH:
                    core_state <= ST_FETCH_WAIT;
                ST_FETCH_WAIT: begin
                    if (!mem_rbusy) begin
                        instr <= mem_rdata;
                        rs1_content <= regs[mem_rdata[19:15]];
                        rs2_content <= regs[mem_rdata[24:20]];
                        core_state <= ST_EXECUTE;
                    end
                end
                ST_EXECUTE: begin
                    PC <= newPC;
                    core_state <= ST_EXECUTE_WAIT;
                end
                ST_EXECUTE_WAIT: begin
                    if (!mem_wbusy && !mem_rbusy) begin
                        core_state <= ST_FETCH;
                        instret <= instret + 1;
                    end
                end
            endcase
        end
    end

`ifndef SYNTHESIS
    logic [7:0][15:0] core_state_text;
    always_comb begin
        case (core_state)
            ST_FETCH:           core_state_text = "ST_FETCH";
            ST_FETCH_WAIT:      core_state_text = "ST_FETCH_WAIT";
            ST_EXECUTE:         core_state_text = "ST_EXECUTE";
            ST_EXECUTE_WAIT:    core_state_text = "ST_EXECUTE_WAIT";
            default:            core_state_text = "UNKNOWN";
        endcase
    end
`endif

    // Store

    always_comb begin
        store_wmask = '0;
        store_data  = '0;

        if (core_state == ST_EXECUTE && opcode == leorv32_pkg::OP_STORE) begin
            case (funct3)  // Width
                leorv32_pkg::FUNC_SB:
                case (store_address[1:0])
                    2'b00: begin
                        store_wmask = 4'b0001;
                        store_data  = rs2_content & 32'h000000FF;
                    end
                    2'b01: begin
                        store_wmask = 4'b0010;
                        store_data  = (rs2_content & 32'h000000FF) << 8;
                    end
                    2'b10: begin
                        store_wmask = 4'b0100;
                        store_data  = (rs2_content & 32'h000000FF) << 16;
                    end
                    2'b11: begin
                        store_wmask = 4'b1000;
                        store_data  = (rs2_content & 32'h000000FF) << 24;
                    end
                endcase
                leorv32_pkg::FUNC_SH:
                case (store_address[1:0])
                    2'b00: begin
                        store_wmask = 4'b0011;
                        store_data  = rs2_content & 32'h0000FFFF;
                    end
                    2'b10: begin
                        store_wmask = 4'b1100;
                        store_data  = rs2_content << 16;
                    end
                endcase
                leorv32_pkg::FUNC_SW: begin
                    store_wmask = 4'b1111;
                    store_data  = rs2_content;
                end
            endcase
        end
    end

    // ALU

    logic [31: 0] alu_input1;
    logic [31: 0] alu_input2;

    assign alu_input1 = rs1_content;
    assign alu_input2 = opcode == leorv32_pkg::OP_ARITH ? rs2_content : I_type_imm;

    logic [31: 0] alu_add;
    logic [31: 0] alu_subtract;

    logic [31: 0] alu_and;
    logic [31: 0] alu_or;
    logic [31: 0] alu_xor;

    logic alu_lt;
    logic alu_ltu;
    logic alu_eq;

    leorv32_alu leorv32_alu (
        .input1(alu_input1),
        .input2(alu_input2),

        .result_add(alu_add),
        .result_subtract(alu_subtract),

        .result_and(alu_and),
        .result_or (alu_or),
        .result_xor(alu_xor),

        .result_lt (alu_lt),
        .result_ltu(alu_ltu),
        .result_eq (alu_eq)
    );

    // Shifter

    logic [4:0] shift_amount;
    assign shift_amount = opcode == leorv32_pkg::OP_IMM ? I_type_imm[4:0] : rs2_content[4:0];

    logic [31:0] rs1_content_r;
    genvar i;
    for (i = 0; i < 32; i = i + 1) assign rs1_content_r[i] = rs1_content[31-i];

    logic [31:0] shifter_input;
    assign shifter_input = funct3[2] ? rs1_content : rs1_content_r;

    logic [31:0] shifter_out;

    barrel_shifter_right barrel_shifter_right (
        .data_in (shifter_input),
        .shift   (shift_amount),
        .arith   (funct7[5]),      // TODO own signals
        .data_out(shifter_out)
    );

    logic [31:0] shifter_out_r;

    for (i = 0; i < 32; i = i + 1) assign shifter_out_r[i] = shifter_out[31-i];

    logic [31:0] shifter_result;
    assign shifter_result = funct3[2] ? shifter_out : shifter_out_r;


    // Write back logic

    logic writeBack;
    logic [31: 0] writeBackData;

    always_comb begin
        writeBack = 1'b0;
        if (core_state == ST_EXECUTE) begin
            case (opcode)
                leorv32_pkg::OP_IMM:    writeBack = 1'b1;
                leorv32_pkg::OP_ARITH:  writeBack = 1'b1;
                leorv32_pkg::OP_LUI:    writeBack = 1'b1;
                leorv32_pkg::OP_AUIPC:  writeBack = 1'b1;
                leorv32_pkg::OP_JAL:    writeBack = 1'b1;
                leorv32_pkg::OP_JALR:   writeBack = 1'b1;
                leorv32_pkg::OP_SYSTEM: if (rs1_content == 0) writeBack = 1'b1;
            endcase
        end else if (core_state == ST_EXECUTE_WAIT) begin
            case (opcode)
                leorv32_pkg::OP_LOAD: writeBack = 1'b1;
            endcase
        end
    end

    always_comb begin
        writeBackData = '0;
        if (core_state == ST_EXECUTE) begin
            case (opcode)
                leorv32_pkg::OP_IMM:
                    case (funct3)
                        leorv32_pkg::FUNC_ADDI:       writeBackData = alu_add;
                        leorv32_pkg::FUNC_SLTI:       writeBackData = {31'b0, alu_lt};
                        leorv32_pkg::FUNC_SLTIU:      writeBackData = {31'b0, alu_ltu};
                        leorv32_pkg::FUNC_ANDI:       writeBackData = alu_and;
                        leorv32_pkg::FUNC_ORI:        writeBackData = alu_or;
                        leorv32_pkg::FUNC_XORI:       writeBackData = alu_xor;
                        leorv32_pkg::FUNC_SLLI:       writeBackData = shifter_result;
                        leorv32_pkg::FUNC_SRLI_SRAI:
                            case(I_type_imm[11:5])
                                7'b0000000: writeBackData = shifter_result;
                                7'b0100000: writeBackData = shifter_result;
                            endcase
                    endcase
                leorv32_pkg::OP_ARITH:
                    case (funct3)
                        leorv32_pkg::FUNC_ADD_SUB:
                            case(funct7)
                                7'b0000000: writeBackData = alu_add;
                                7'b0100000: writeBackData = alu_subtract;
                            endcase
                        leorv32_pkg::FUNC_SLT:          writeBackData = {31'b0, alu_lt};
                        leorv32_pkg::FUNC_SLTU:         writeBackData = {31'b0, alu_ltu};
                        leorv32_pkg::FUNC_AND:          writeBackData = alu_and;
                        leorv32_pkg::FUNC_OR:           writeBackData = alu_or;
                        leorv32_pkg::FUNC_XOR:          writeBackData = alu_xor;
                        leorv32_pkg::FUNC_SLL:          writeBackData = shifter_result;
                        leorv32_pkg::FUNC_SRL_SRA:
                            case(funct7)
                                7'b0000000: writeBackData = shifter_result;
                                7'b0100000: writeBackData = shifter_result;
                            endcase
                    endcase
                leorv32_pkg::OP_LUI:    writeBackData = U_type_imm;
                leorv32_pkg::OP_AUIPC:  writeBackData = PC + U_type_imm;
                leorv32_pkg::OP_JAL:    writeBackData = PCplus4;
                leorv32_pkg::OP_JALR:   writeBackData = PCplus4;
                leorv32_pkg::OP_SYSTEM:
                    case (funct3)
                        leorv32_pkg::FUNC_CSRRW: ;
                        leorv32_pkg::FUNC_CSRRS:
                            case (I_type_imm[11:0]) // CSR
                                leorv32_pkg::CSR_RDCYCLE:     writeBackData = cycles[31:0];
                                leorv32_pkg::CSR_RDCYCLEH:    writeBackData = cycles[63:32];
                                leorv32_pkg::CSR_RDTIME:      writeBackData = cycles[31:0];
                                leorv32_pkg::CSR_RDTIMEH:     writeBackData = cycles[63:32];
                                leorv32_pkg::CSR_RDINSTRET:   writeBackData = instret[31:0];
                                leorv32_pkg::CSR_RDINSTRETH:  writeBackData = instret[63:32];
                                leorv32_pkg::CSR_MHARTID:     writeBackData = MHARTID | {31'b0, mhartid_0};
                            endcase
                        leorv32_pkg::FUNC_CSRRC:  ;
                        leorv32_pkg::FUNC_CSRRWI: ;
                        leorv32_pkg::FUNC_CSRRSI: ;
                        leorv32_pkg::FUNC_CSRRCI: ;
                    endcase
            endcase
        end else if (core_state == ST_EXECUTE_WAIT) begin
            case (opcode)
                leorv32_pkg::OP_LOAD:
                case (funct3)  // Width
                    leorv32_pkg::FUNC_LB:
                            case (load_address[1:0])
                                2'b00: writeBackData = {{24{mem_rdata[7]}}, mem_rdata[7:0]};
                                2'b01: writeBackData = {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                                2'b10: writeBackData = {{24{mem_rdata[23]}}, mem_rdata[23:16]};
                                2'b11: writeBackData = {{24{mem_rdata[31]}}, mem_rdata[31:24]};
                            endcase
                    leorv32_pkg::FUNC_LH:
                            case (load_address[1])
                                1'b0: writeBackData = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
                                1'b1: writeBackData = {{16{mem_rdata[23]}}, mem_rdata[31:16]};
                            endcase
                    leorv32_pkg::FUNC_LW:
                            begin
                                writeBackData = mem_rdata;
                            end
                    leorv32_pkg::FUNC_LBU:
                            case (load_address[1:0])
                                2'b00: writeBackData = {{24{1'b0}}, mem_rdata[7:0]};
                                2'b01: writeBackData = {{24{1'b0}}, mem_rdata[15:8]};
                                2'b10: writeBackData = {{24{1'b0}}, mem_rdata[23:16]};
                                2'b11: writeBackData = {{24{1'b0}}, mem_rdata[31:24]};
                            endcase
                    leorv32_pkg::FUNC_LHU:
                            case (load_address[1])
                                1'b0: writeBackData = {{16{1'b0}}, mem_rdata[15:0]};
                                1'b1: writeBackData = {{16{1'b0}}, mem_rdata[31:16]};
                            endcase
                endcase
            endcase
        end
    end

    // PC

    logic [ADDR_WIDTH-1: 0] newPC;
    logic [ADDR_WIDTH-1: 0] PCplus4;

    assign PCplus4 = PC + 4;

    always_comb begin
        // Increment PC, overwritten by jumps and branches
        newPC = PCplus4;
        if (core_state == ST_EXECUTE) begin
            case (opcode)
                leorv32_pkg::OP_JAL:    newPC = PC + J_type_imm;
                leorv32_pkg::OP_JALR:   newPC = ((rs1_content + I_type_imm) & 32'hFFFFFFFE);
                leorv32_pkg::OP_BRANCH:
                    case (funct3)
                        leorv32_pkg::FUNC_BEQ:  newPC = rs1_content == rs2_content ? PC + B_type_imm : PCplus4;
                        leorv32_pkg::FUNC_BNE:  newPC = rs1_content != rs2_content ? PC + B_type_imm : PCplus4;
                        leorv32_pkg::FUNC_BLTU: newPC = rs1_content <  rs2_content ? PC + B_type_imm : PCplus4;
                        leorv32_pkg::FUNC_BGEU: newPC = rs1_content >= rs2_content ? PC + B_type_imm : PCplus4;
                        leorv32_pkg::FUNC_BLT:  newPC = $signed(rs1_content) <  $signed(rs2_content) ? PC + B_type_imm : PCplus4;
                        leorv32_pkg::FUNC_BGE:  newPC = $signed(rs1_content) >= $signed(rs2_content) ? PC + B_type_imm : PCplus4;
                    endcase
            endcase
        end
    end

    // Counters

    logic [63: 0]  cycles;
    logic [63: 0]  instret;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            cycles <= '0;
        end else cycles <= cycles + 1;
    end

endmodule
