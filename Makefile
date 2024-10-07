needed_verilog_files = top.v core.v comparator.v alu.v registers.v

.PHONY: sim
sim: target/verilator/Vtb_core
	$<

target/verilator/Vtb_core: | target
	@# TODO consider using -Wall
	verilator +1364-2005ext+v +define+simulation --binary -j 0 tb_core.v -Mdir $(@D)

target:
	mkdir target

target/cpu.json: $(needed_verilog_files) | target
	yosys -p "read_verilog $(needed_verilog_files); synth_ecp5 -json $@"

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
