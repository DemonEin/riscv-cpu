# set this to the prefix of the gcc and binutils binaries, for example,
# this is what I use
gcc_binary_prefix = ~/riscv-gcc/bin/riscv32-elf-

needed_verilog_files = top.v core.v comparator.v alu.v registers.v
program_files = blink.s blink.c

.PHONY: sim
sim: target/verilator/Vtb_top
	$<

target/verilator/Vtb_top: tb_top.v target/memory.hex target/entry.txt $(needed_verilog_files) | target
	@# TODO consider using -Wall
	verilator +1364-2005ext+v +define+simulation +define+INITIAL_PROGRAM_COUNTER=$$(cat target/entry.txt) --binary -j 0 $< -Mdir $(@D)

target:
	mkdir target

target/a.out: $(program_files) linker-script | target
	$(gcc_binary_prefix)gcc -march=rv32i -mabi=ilp32 -T linker-script -nostdlib -o $@ $(program_files)

target/memory.bin target/entry.txt &: target/a.out | target
	cargo run --manifest-path loader/Cargo.toml -- \
		--memory target/memory.bin --entry target/entry.txt target/a.out

target/memory.hex: target/memory.bin | target
	hexdump -v -e '/1 "%x "' $< > $@

target/cpu.json: $(needed_verilog_files) target/memory.hex target/entry.txt | target
	yosys -p "read_verilog -DINITIAL_PROGRAM_COUNTER=$$(cat target/entry.txt) $(needed_verilog_files); synth_ecp5 -json $@"

target/cpu.config: target/cpu.json orangecrab.lpf
	nextpnr-ecp5 --85k --package CSFBGA285 --lpf orangecrab.lpf --json $< --textcfg $@

target/cpu.bit: target/cpu.config
	ecppack --compress --freq 38.8 --input $< --bit $@

target/cpu.dfu: target/cpu.bit
	cp $< $@
	dfu-suffix -v 1209 -p 5af0 --add $@

.PHONY: install
install: target/cpu.dfu
	dfu-util --alt 0 -D $<

.PHONY: clean
clean:
	rm -rf target
