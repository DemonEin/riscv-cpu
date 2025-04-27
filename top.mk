# top level make file included by each program/test

# set this to the prefix of the gcc and binutils binaries, for example,
# this is what I use
gcc_binary_prefix = ~/riscv-gcc/bin/riscv32-elf-

# includes trailing slash
current_directory := $(dir $(lastword $(MAKEFILE_LIST)))

# the top files must be included before their dependencies for yosys
needed_verilog_files := $(foreach file, top.v core.v comparator.v alu.v registers.v usb_constants.v usb.v, $(current_directory)cpu/$(file))

VERILATOR_OPTIONS := +1364-2005ext+v -Wwarn-BLKSEQ -y $(current_directory)cpu
GCC_OPTIONS := -march=rv32i_zicsr -mabi=ilp32 -std=c23 -Wpedantic

testbench ?= $(current_directory)/tb_top.v

target_directory := $(current_directory)target/$(shell realpath --relative-to $(current_directory) .)
linker_script := $(current_directory)linker-script
lib := $(current_directory)lib
lib_target_directory := $(current_directory)target/lib
simulation_cpulib.o := $(lib_target_directory)/simulation/cpulib.o
hardware_cpulib.o := $(lib_target_directory)/hardware/cpulib.o
ifndef no_link_library
	simulation_cpulib_argument := $(simulation_cpulib.o)
	hardware_cpulib_argument := $(hardware_cpulib.o)
endif

picolibc_configure_directory := $(current_directory)target/lib/picolibc/configure
picolibc_install_directory := $(current_directory)target/lib/picolibc/install
libc.a := $(picolibc_install_directory)/lib/rv32i/ilp32/libc.a
libc_headers := $(picolibc_install_directory)/include

.NOTINTERMEDIATE:

$(target_directory)/verilator/sim: $(testbench) $(target_directory)/simulation/memory.hex $(target_directory)/simulation/entry.txt $(needed_verilog_files)
	verilator $(VERILATOR_OPTIONS) \
		+define+simulation \
		+define+INITIAL_PROGRAM_COUNTER=$$(cat $(target_directory)/simulation/entry.txt) \
		+define+MEMORY_FILE=\"$(target_directory)/simulation/memory.hex\" \
		--binary \
		-j 0 \
		$(testbench) \
		-Mdir $(@D) \
		-o $(@F)

binary_prerequisites = $(program_files) $(cpulib_argument) $(linker_script) $(libc_headers) $(libc.a)
binary_build_command = $(gcc_binary_prefix)gcc \
                               $(GCC_OPTIONS) \
                               -I $(current_directory) \
                               -T $(linker_script) \
                               -nostdlib \
                               -o $@ \
                               $(program_files) \
                               $(cpulib_argument) \
                               -I$(libc_headers) \
                               $(libc.a) \
                               -lgcc \
                               -Os \
                               -ggdb

cpulib_argument := $(simulation_cpulib_argument)
$(target_directory)/simulation/a.out: $(binary_prerequisites) | $(target_directory)/simulation
	$(binary_build_command)

cpulib_argument := $(hardware_cpulib_argument)
$(target_directory)/hardware/a.out: $(binary_prerequisites) | $(target_directory)/hardware
	$(binary_build_command)

%/memory.bin %/entry.txt &: %/a.out | %
	cargo run --manifest-path $(current_directory)loader/Cargo.toml -- \
		--memory $*/memory.bin --entry $*/entry.txt $<

%/memory.hex: %/memory.bin | %
	hexdump -v -e '/4 "%x "' $< > $@

cpulib_prerequisites := $(lib)/cpulib.h $(lib)/cpulib.c $(lib)/cpulib.s $(lib)/usb.c $(libc_headers)
cpulib_build_command = $(gcc_binary_prefix)gcc \
						$(GCC_OPTIONS) \
						-r \
						$(lib)/cpulib.c \
						$(lib)/cpulib.s \
						$(lib)/usb.c \
						-I$(libc_headers) \
						-o $@ \
						-Os \
						-ggdb

$(simulation_cpulib.o): $(cpulib_prerequisites) | $(lib_target_directory)/simulation
	$(cpulib_build_command) -D SIMULATION

$(hardware_cpulib.o): $(cpulib_prerequisites) | $(lib_target_directory)/hardware
	$(cpulib_build_command)

$(target_directory) $(target_directory)/simulation $(target_directory)/hardware $(current_directory)target/lib/simulation $(current_directory)target/lib/hardware:
	mkdir -p $@

$(libc.a) $(libc_headers) &: $(lib)/picolibc
	meson setup $(picolibc_configure_directory) \
		$(lib)/picolibc \
		-Dmultilib-list=rv32i/ilp32 \
		-Dincludedir=include \
		-Dlibdir=lib \
		-Dprefix=$$(pwd)/$(picolibc_install_directory) \
		--cross-file $(lib)/cross-riscv32-unknown-elf.txt

	cd $(picolibc_configure_directory) && \
		ninja && \
		ninja install

$(target_directory)/cpu.json: $(needed_verilog_files) $(target_directory)/hardware/memory.hex $(target_directory)/hardware/entry.txt
	@# run verilator --lint-only before building because yosys does not report many simple errors
	INITIAL_PROGRAM_COUNTER=$$(cat $(target_directory)/hardware/entry.txt) && \
	verilator  --lint-only $(VERILATOR_OPTIONS) +define+INITIAL_PROGRAM_COUNTER=$$INITIAL_PROGRAM_COUNTER +define+MEMORY_FILE='"$(target_directory)/hardware/memory.hex"' top.v && \
	yosys -p "read_verilog -DYOSYS -DINITIAL_PROGRAM_COUNTER=$$INITIAL_PROGRAM_COUNTER -DMEMORY_FILE=\"$(target_directory)/hardware/memory.hex\" $(needed_verilog_files); synth_ecp5 -json $@"

%.config: %.json $(current_directory)cpu/orangecrab.lpf
	nextpnr-ecp5 --85k --package CSFBGA285 --lpf $(current_directory)cpu/orangecrab.lpf --json $< --textcfg $@

%.bit: %.config
	ecppack --compress --freq 38.8 --input $< --bit $@

%.dfu: %.bit
	cp $< $@
	dfu-suffix -v 1209 -p 5af0 --add $@

.PHONY: install
install: $(target_directory)/cpu.dfu
	dfu-util --alt 0 -D $<

.PHONY: sim
sim: $(target_directory)/verilator/sim
	$<

.PHONY: synth
synth: $(target_directory)/cpu.json

.PHONY: clean
clean:
	rm -rf $(current_directory)target

.PHONY: readelf
readelf: $(target_directory)/a.out
	readelf -a $<

.PHONY: disassemble
disassemble: $(target_directory)/a.out
	$(gcc_binary_prefix)objdump -d $<

