.PHONY: sim
sim: build_simulation
	obj_dir/Vtb_core

.PHONY: build_simulation
build_simulation:
	@# TODO consider using -Wall
	verilator +1364-2005ext+v +define+simulation --binary -j 0 tb_core.v

.PHONY: synth
synth:
	yosys -p 'read_verilog core.v comparator.v alu.v registers.v; synth_ecp5; stat'

.PHONY: clean
clean:
	rm -rf obj_dir
