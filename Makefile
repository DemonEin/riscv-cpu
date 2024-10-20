# set this to the prefix of the gcc and binutils binaries, for example,
# this is what I use
gcc_binary_prefix = ~/riscv-gcc/bin/riscv32-elf-

needed_verilog_files = top.v core.v comparator.v alu.v registers.v

%/verilator/Vtb_top: tb_top.v %/memory.hex %/entry.txt $(needed_verilog_files)
	@# TODO consider using -Wall
	verilator +1364-2005ext+v +define+simulation +define+INITIAL_PROGRAM_COUNTER=$$(cat $*/entry.txt) +define+MEMORY_FILE=\"$*/memory.hex\" --binary -j 0 tb_top.v $(needed_verilog_files) -Mdir $(@D)

%/a.out: $(program_files) linker-script | %
	$(gcc_binary_prefix)gcc -march=rv32i -mabi=ilp32 -T linker-script -nostdlib -o $@ $(program_files)

%/memory.bin %/entry.txt &: %/a.out
	cargo run --manifest-path loader/Cargo.toml -- \
		--memory $*/memory.bin --entry $*/entry.txt $<

%.hex: %.bin
	hexdump -v -e '/1 "%x "' $< > $@

$(target_directory):
	mkdir -p $@

%/cpu.json: $(needed_verilog_files) %/memory.hex %/entry.txt
	@# run verilator --lint-only before building because yosys does not report many simple errors
	INITIAL_PROGRAM_COUNTER=$$(cat $*/entry.txt) && \
	verilator +1364-2005ext+v --lint-only +define+INITIAL_PROGRAM_COUNTER=$$INITIAL_PROGRAM_COUNTER +define+MEMORY_FILE='"$*/memory.hex"' $(needed_verilog_files) && \
	yosys -p "read_verilog -DINITIAL_PROGRAM_COUNTER=$$INITIAL_PROGRAM_COUNTER -DMEMORY_FILE=\"$*/memory.hex\" $(needed_verilog_files); synth_ecp5 -json $@"

%.config: %.json orangecrab.lpf
	nextpnr-ecp5 --85k --package CSFBGA285 --lpf orangecrab.lpf --json $< --textcfg $@

%.bit: %.config
	ecppack --compress --freq 38.8 --input $< --bit $@

%.dfu: %.bit
	cp $< $@
	dfu-suffix -v 1209 -p 5af0 --add $@

.PHONY: install
install: $(target_directory)/cpu.dfu
	dfu-util --alt 0 -D $<

.PHONY: sim
sim: $(target_directory)/verilator/Vtb_top
	$<

.PHONY: test
test:
	make sim target_directory=target/test program_files=test.s

.PHONY: blinkinstall
blinkinstall:
	make install target_directory=target/blink program_files="blink.s blink.c"

.PHONY: clean
clean:
	rm -rf target

.PHONY: readelf
readelf: target/a.out
	readelf -a $<

.PHONY: disassemble
objdump: target/a.out
	$(gcc_binary_prefix)objdump -D $<
