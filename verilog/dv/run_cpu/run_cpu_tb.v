// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

`timescale 1 ns / 1 ps

module run_cpu_tb;
    parameter CLOCK_PERIOD_NS = 25;  // 20 MHz clock
    parameter BAUDRATE = 9600;
    parameter SER_BIT_PERIOD_NS = 1000000000/9600;

    reg my_clock;
    reg RSTB;
    reg CSB;
    reg power1, power2;
    reg power3, power4;

    wire gpio;
    wire [37:0] mprj_io;

    assign mprj_io[3] = 1'b1;

    // External clock is used by default.  Make this artificially fast for the
    // simulation.  Normally this would be a slow clock and the digital PLL
    // would be the fast clock.

    initial begin
        my_clock = 1'b0;
    end

    always #(CLOCK_PERIOD_NS/2) my_clock <= !my_clock;

    wire clock;
    
    assign clock = my_clock;

    integer j;
    initial begin
        $dumpfile("run_cpu.vcd");
        $dumpvars(0, run_cpu_tb);
        for (int i = 0; i < 32; i++) $dumpvars(0, uut.mprj.soc_inst.leorv32_core0.regs[i]);
        for (int i = 0; i < 32; i++) $dumpvars(0, uut.mprj.soc_inst.leorv32_core1.regs[i]);

        // Repeat cycles of 1000 clock edges as needed to complete testbench
        repeat (400) begin
            repeat (1000) @(posedge my_clock);
            $display("+1000 cycles");
        end

        $display("memory dump");
        $display("  mem0  \t  mem1  ");
        for (j=0;j<512;j++) begin
            //$display("[%h] : %h \t [%h] : %h \t [%h] : %h \t [%h] : %h", j, uut.mprj.soc_inst.wram.memory[0].sky130_sram_2kbyte_1rw1r_32x512_8.mem[j], j, uut.mprj.soc_inst.wram.memory[1].sky130_sram_2kbyte_1rw1r_32x512_8.mem[j], j, uut.mprj.soc_inst.wram.memory[2].sky130_sram_2kbyte_1rw1r_32x512_8.mem[j], j, uut.mprj.soc_inst.wram.memory[3].sky130_sram_2kbyte_1rw1r_32x512_8.mem[j]);
            $display("[%h] : %h \t [%h] : %h \t [%h] : %h \t [%h] : %h", j, uut.mprj.soc_inst.wram.mem0.mem[j], j, uut.mprj.soc_inst.wram.mem1.mem[j], j, uut.mprj.soc_inst.wram.mem2.mem[j], j, uut.mprj.soc_inst.wram.mem3.mem[j]);
        end

        $display("%c[1;31m",27);
        `ifdef GL
            $display ("Monitor: Timeout, Test Mega-Project WB WFG (GL) Failed");
        `else
            $display ("Monitor: Timeout, Test Mega-Project WB WFG (RTL) Failed");
        `endif
        $display("%c[0m",27);

        $finish;
    end
    
    initial begin
        //$readmemh("firmware_0.hex", uut.mprj.soc_inst.wram.memory[0].sky130_sram_2kbyte_1rw1r_32x512_8.mem);
        //$readmemh("firmware_1.hex", uut.mprj.soc_inst.wram.memory[1].sky130_sram_2kbyte_1rw1r_32x512_8.mem);
        //$readmemh("firmware_2.hex", uut.mprj.soc_inst.wram.memory[2].sky130_sram_2kbyte_1rw1r_32x512_8.mem);
        //$readmemh("firmware_3.hex", uut.mprj.soc_inst.wram.memory[3].sky130_sram_2kbyte_1rw1r_32x512_8.mem);
        $readmemh("firmware_0.hex", uut.mprj.soc_inst.wram.mem0.mem);
        $readmemh("firmware_1.hex", uut.mprj.soc_inst.wram.mem1.mem);
        $readmemh("firmware_2.hex", uut.mprj.soc_inst.wram.mem2.mem);
        $readmemh("firmware_3.hex", uut.mprj.soc_inst.wram.mem3.mem);
    end

    reg [7:0] recv_byte = 0;
    wire ser_tx;
    
    assign ser_tx = mprj_io[6];
    
    always @(negedge ser_tx) begin
        read_byte_ser;
    end

    task automatic read_byte_ser;
        #(SER_BIT_PERIOD_NS / 2);  // Wait half baud
        if ((ser_tx == 0)) begin

            #SER_BIT_PERIOD_NS;

            // Read data LSB first
            for (int j = 0; j < 8; j++) begin
                recv_byte[j] = ser_tx;
                #SER_BIT_PERIOD_NS;
            end

            if ((ser_tx == 1)) begin
                //$write(colors::Green);
                $display("leorv32 --> uart: 0x%h '%c'", recv_byte, recv_byte);
                //$write(colors::None);
            end
        end
    endtask

    initial begin
        $display("Monitor: MPRJ-Logic WB WFG Started");
        
        wait(recv_byte === "H");
        wait(recv_byte === "e");
        wait(recv_byte === "l");
        wait(recv_byte === "l");
        wait(recv_byte === "o");
        
        #(10*SER_BIT_PERIOD_NS);
        
        $display("memory dump");
        $display("  mem0  \t  mem1  ");
        for (j=0;j<512;j++) begin
            //$display("[%h] : %h \t [%h] : %h \t [%h] : %h \t [%h] : %h", j, uut.mprj.soc_inst.wram.memory[0].sky130_sram_2kbyte_1rw1r_32x512_8.mem[j], j, uut.mprj.soc_inst.wram.memory[1].sky130_sram_2kbyte_1rw1r_32x512_8.mem[j], j, uut.mprj.soc_inst.wram.memory[2].sky130_sram_2kbyte_1rw1r_32x512_8.mem[j], j, uut.mprj.soc_inst.wram.memory[3].sky130_sram_2kbyte_1rw1r_32x512_8.mem[j]);
            $display("[%h] : %h \t [%h] : %h \t [%h] : %h \t [%h] : %h", j, uut.mprj.soc_inst.wram.mem0.mem[j], j, uut.mprj.soc_inst.wram.mem1.mem[j], j, uut.mprj.soc_inst.wram.mem2.mem[j], j, uut.mprj.soc_inst.wram.mem3.mem[j]);
        end

        `ifdef GL
            $display("Monitor: Mega-Project WB WFG (GL) Passed");
        `else
            $display("Monitor: Mega-Project WB WFG (RTL) Passed");
        `endif
        $finish;
    end

    initial begin
        RSTB <= 1'b0;
        CSB  <= 1'b1;        // Force CSB high
        #2000;
        RSTB <= 1'b1;            // Release reset
        #100000;
        CSB = 1'b0;        // CSB can be released
    end

    initial begin        // Power-up sequence
        power1 <= 1'b0;
        power2 <= 1'b0;
        power3 <= 1'b0;
        power4 <= 1'b0;
        #100;
        power1 <= 1'b1;
        #100;
        power2 <= 1'b1;
        #100;
        power3 <= 1'b1;
        #100;
        power4 <= 1'b1;
    end

    wire flash_csb;
    wire flash_clk;
    wire flash_io0;
    wire flash_io1;

    wire VDD3V3 = power1;
    wire VDD1V8 = power2;
    wire USER_VDD3V3 = power3;
    wire USER_VDD1V8 = power4;
    wire VSS = 1'b0;

    caravel uut (
        .vddio      (VDD3V3),
        .vddio_2  (VDD3V3),
        .vssio      (VSS),
        .vssio_2  (VSS),
        .vdda      (VDD3V3),
        .vssa      (VSS),
        .vccd      (VDD1V8),
        .vssd      (VSS),
        .vdda1    (VDD3V3),
        .vdda1_2  (VDD3V3),
        .vdda2    (VDD3V3),
        .vssa1      (VSS),
        .vssa1_2  (VSS),
        .vssa2      (VSS),
        .vccd1      (VDD1V8),
        .vccd2      (VDD1V8),
        .vssd1      (VSS),
        .vssd2      (VSS),
        .clock    (clock),
        .gpio     (gpio),
        .mprj_io  (mprj_io),
        .flash_csb(flash_csb),
        .flash_clk(flash_clk),
        .flash_io0(flash_io0),
        .flash_io1(flash_io1),
        .resetb      (RSTB)
    );

    spiflash #(
        .FILENAME("run_cpu.hex")
    ) spiflash (
        .csb(flash_csb),
        .clk(flash_clk),
        .io0(flash_io0),
        .io1(flash_io1),
        .io2(),            // not used
        .io3()             // not used
    );
    

endmodule
`default_nettype wire
