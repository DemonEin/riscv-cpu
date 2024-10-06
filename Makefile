build_directory = build

VPATH = $(build_directory)

.PHONY: sim
sim: verilator/Vtb_core
	$(build_directory)/$<

verilator/Vtb_core: $(build_directory)
	@# TODO consider using -Wall
	verilator +1364-2005ext+v +define+simulation --binary -j 0 tb_core.v -Mdir $(build_directory)/verilator

$(build_directory):
	mkdir $(build_directory)

.PHONY: synth
synth:
	yosys -p 'read_verilog core.v comparator.v alu.v registers.v; synth_ecp5; stat'

.PHONY: clean
clean:
	rm -rf $(build_directory)
