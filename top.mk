# top level make file included by each program/test

# set this to the prefix of the gcc and binutils binaries, for example,
# this is what I use
gcc_binary_prefix = ~/riscv-gcc/bin/riscv32-elf-

# includes trailing slash
current_directory := $(dir $(lastword $(MAKEFILE_LIST)))

needed_verilog_files := $(foreach file, top.v core.v comparator.v alu.v registers.v csr.v usb.v, $(current_directory)$(file))

VERILATOR_OPTIONS := +1364-2005ext+v -Wwarn-BLKSEQ
GCC_OPTIONS := -march=rv32i_zicsr -mabi=ilp32

testbench ?= $(current_directory)/tb_top.v

target_directory := $(current_directory)target/$(shell realpath --relative-to $(current_directory) .)
linker_script := $(current_directory)linker-script
lib := $(current_directory)lib
cpulib.o := $(current_directory)target/lib/cpulib.o

.NOTINTERMEDIATE:

%/verilator/sim: $(testbench) %/memory.hex %/entry.txt $(needed_verilog_files)
	verilator $(VERILATOR_OPTIONS) +define+simulation +define+INITIAL_PROGRAM_COUNTER=$$(cat $*/entry.txt) +define+MEMORY_FILE=\"$*/memory.hex\" --binary -j 0 $(testbench) $(needed_verilog_files) -Mdir $(@D) -o $(@F)

%/a.out: $(program_files) $(cpulib.o) $(linker_script) | %
	$(gcc_binary_prefix)gcc $(GCC_OPTIONS) -I $(current_directory) -T $(linker_script) -nostdlib -o $@ $(program_files) $(cpulib.o)

%/memory.bin %/entry.txt &: %/a.out
	cargo run --manifest-path $(current_directory)loader/Cargo.toml -- \
		--memory $*/memory.bin --entry $*/entry.txt $<

%.hex: %.bin
	hexdump -v -e '/4 "%x "' $< > $@

$(cpulib.o): $(lib)/cpulib.h $(lib)/cpulib.c $(lib)/cpulib.s | $(current_directory)target/lib
	$(gcc_binary_prefix)gcc $(GCC_OPTIONS) -r $(lib)/cpulib.c $(lib)/cpulib.s -o $@

$(target_directory):
	mkdir -p $@

$(current_directory)target/lib:
	mkdir -p $@

%/cpu.json: $(needed_verilog_files) %/memory.hex %/entry.txt
	@# run verilator --lint-only before building because yosys does not report many simple errors
	INITIAL_PROGRAM_COUNTER=$$(cat $*/entry.txt) && \
	verilator  --lint-only $(VERILATOR_OPTIONS) +define+INITIAL_PROGRAM_COUNTER=$$INITIAL_PROGRAM_COUNTER +define+MEMORY_FILE='"$*/memory.hex"' $(needed_verilog_files) && \
	yosys -p "read_verilog -DINITIAL_PROGRAM_COUNTER=$$INITIAL_PROGRAM_COUNTER -DMEMORY_FILE=\"$*/memory.hex\" $(needed_verilog_files); synth_ecp5 -json $@"

%.config: %.json $(current_directory)orangecrab.lpf
	nextpnr-ecp5 --85k --package CSFBGA285 --lpf $(current_directory)orangecrab.lpf --json $< --textcfg $@

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

.PHONY: usbsim
usbsim: $(target_directory)/verilator/sim $(current_directory)usbtestdata
	diff <( cargo run --manifest-path $(current_directory)usb-encode/Cargo.toml < $(current_directory)usbtestdata \
		| $< \
		| head -c $$(wc -c < $(current_directory)usbtestdata) ) \
	($(current_directory)usbtestdata

.PHONY: test
test:
	make sim target_directory=target/test program_files=test.s

.PHONY: testsynth
testsynth: 
	make target/test/cpu.json target_directory=target/test program_files=test.s

.PHONY: clean
clean:
	rm -rf $(current_directory)target

.PHONY: readelf
readelf: $(target_directory)/a.out
	readelf -a $<

.PHONY: disassemble
disassemble: $(target_directory)/a.out
	$(gcc_binary_prefix)objdump -d $<

.PHONY: usbtest
usbtest:
	make usbsim target_directory=target/usbtest program_files="usbtest.c" testbench=tb_usb.v

target/usb:
	mkdir -p $@

