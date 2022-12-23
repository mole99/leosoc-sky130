default: build

BOARD ?= icebreaker
TOOLCHAIN_PREFIX ?= riscv32-unknown-elf-
PYTHON ?= python3

FIRMWARE_OBJS = firmware/start.o firmware/main.o
GCC_WARNS  = -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic # -Wconversion

# Sources
RTL = $(wildcard leorv32/rtl/*.sv) $(wildcard soc/rtl/*.sv) $(wildcard uart/rtl/*.sv) $(wildcard util/rtl/*.sv) $(wildcard svga/rtl/*.sv) $(wildcard sram/rtl/*.sv)
TB = $(wildcard soc/tb/*.sv)

# --- Generic Targets ---

sim: sim-${BOARD}

view: view-${BOARD}

synth: synth-${BOARD}

build: build-${BOARD}

upload: upload-${BOARD}

# --- iCEBreaker ---

sim-icebreaker.vvp: $(RTL) $(TB) firmware/firmware.hex
	iverilog -Wall -o $@ -g2012 $(RTL) $(TB) -s icebreaker_top_tb `yosys-config --datdir/ice40/cells_sim.v`

sim-icebreaker: sim-icebreaker.vvp
	vvp $^ -fst
	
view-icebreaker:
	gtkwave icebreaker_top_tb.fst --save gtkwave/save_icebreaker.gtkw

synth-icebreaker: icebreaker.json

build-icebreaker: icebreaker.bit

upload-icebreaker: icebreaker.bit
	iceprog icebreaker.bit

icebreaker.json: $(RTL) firmware/firmware.hex
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'synth_ice40 -top icebreaker_top -json $@' $(RTL)

icebreaker.asc: icebreaker.json
	nextpnr-ice40 --up5k --json $< \
		--pcf constraints/icebreaker.pcf \
		--package sg48 \
		--asc $@

icebreaker.bit: icebreaker.asc
	icepack $< $@

# --- svga ---

sim-svga.vvp: $(RTL) svga/tb/svga_gen_top_tb.sv
	iverilog -Wall -o $@ -g2012 $^ -s svga_gen_top_tb

sim-svga: sim-svga.vvp
	vvp $^ -fst

view-svga:
	gtkwave svga.fst --save gtkwave/save_svga.gtkw

synth-svga: svga.json

build-svga: svga.bit

upload-svga: svga.bit
	iceprog svga.bit

svga.json: svga/rtl/svga_gen.sv svga/rtl/svga_gen_top.sv
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'synth_ice40 -top svga_gen_top -json $@' $(RTL)

svga.asc: svga.json
	nextpnr-ice40 --up5k --json $< \
		--pcf constraints/icebreaker.pcf \
		--package sg48 \
		--asc $@

svga.bit: svga.asc
	icepack $< $@

# --- ULX3S ---

sim-ulx3s.vvp: $(RTL) $(TB) firmware/firmware.hex
	iverilog -Wall -o $@ -g2012 $(RTL) $(TB) -s ulx3s_top_tb `yosys-config --datdir/ecp5/cells_sim.v`

sim-ulx3s: sim-ulx3s.vvp
	vvp $^ -fst
	
view-ulx3s:
	gtkwave ulx3s_top_tb.fst --save gtkwave/save_ulx3s.gtkw

synth-ulx3s: ulx3s.json

build-ulx3s: ulx3s.bit

upload-ulx3s: ulx3s.bit
	openFPGALoader --board=ulx3s ulx3s.bit

ulx3s.json: $(RTL) firmware/firmware.hex
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'synth_ecp5 -top ulx3s_top -json $@' $(RTL)

ulx3s.config: ulx3s.json
	nextpnr-ecp5 --85k --json $< \
		--lpf constraints/ulx3s_v20.lpf \
		--package CABGA381 \
		--textcfg $@

ulx3s.bit: ulx3s.config
	ecppack $< $@

# --- Firmware ---

firmware/%.o: firmware/%.c
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32i -Os --std=c99 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<

firmware/start.o: firmware/start.S
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32i -o $@ $<

firmware/${BOARD}_sections.lds: firmware/sections.lds
	$(TOOLCHAIN_PREFIX)gcc -E -x c -DBOARD=${BOARD} -o $@ $^

firmware/firmware.elf: $(FIRMWARE_OBJS) firmware/${BOARD}_sections.lds
	$(TOOLCHAIN_PREFIX)gcc  -Os -mabi=ilp32 -march=rv32i -ffreestanding -nostdlib -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,firmware/${BOARD}_sections.lds,-Map,firmware/firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) -lgcc

firmware/firmware.bin: firmware/firmware.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

firmware/firmware.hex: firmware/firmware.bin firmware/makehex.py
	$(PYTHON) firmware/makehex.py $< 2048 > $@

# --- General ---

.PHONY: clean sim view synth build upload \
        sim-icebreaker view-icebreaker synth-icebreaker build-icebreaker upload-icebreaker \
        sim-ulx3s view-ulx3s synth-ulx3s build-ulx3s upload-ulx3s

clean:
	rm -f *.vvp *.fst *.vcd *.log *.json *.asc *.bin *.bit firmware/*.o firmware/*.elf firmware/*.bin firmware/*.hex firmware/firmware.map

# --- Linting ---

lint:
	verible-verilog-lint $(RTL) $(TB) --rules=-unpacked-dimensions-range-ordering

lint-autofix:
	verible-verilog-lint $(RTL) $(TB) --autofix inplace-interactive --rules=-unpacked-dimensions-range-ordering 

format:
	verible-verilog-format --indentation_spaces 4 --module_net_variable_alignment=preserve --case_items_alignment=preserve $(RTL) --inplace --verbose

check-license:
	find . -type f -name "*.sv" -exec head -n 1 {} \;
