# LeoRV32 FPGA

This repository contains FPGA examples for LeoRV32.

# Setup

You need to have a RISC-V toolchain in your `PATH` variable.

Next, setup `TOOLCHAIN_PREFIX` accordingly, for example:

	export TOOLCHAIN_PREFIX=riscv32-unknown-elf-

# Supported Boards

    - icebreaker
    - ulx3s

# Usage

First, export the board for which to generate the bitstream:

	export BOARD=icebreaker

To run a simulation and view it:

	make sim
	make view

The following commands are used to synthesize the design, perform place and route and upload the design to the FPGA board.

	make synth
	make build
	make upload

After that, the green LED on your iCEBreaker should blink (you may need to reset it first).
