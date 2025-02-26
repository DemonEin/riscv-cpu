testbench = tb_usb.v
program_files = usbtest.c

include ../../top.mk

.PHONY: test
test: $(target_directory)/verilator/sim usbtestdata
	diff <( cargo run --manifest-path usb-encode/Cargo.toml < usbtestdata \
		| $< \
		| head -c $$(wc -c < usbtestdata) ) \
	usbtestdata
