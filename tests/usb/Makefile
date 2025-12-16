testbench = tb_usb.v

include ../../top.mk

.PHONY: test
test: $(target_directory)/verilator/sim usbtestdata
	diff <( $< < usbtestdata | head -c $$(wc -c < usbtestdata) ) \
		usbtestdata

# don't perform a diff with the intended output and just run with the input,
# useful when debugging a failing test
.PHONY: simpletest
simpletest: $(target_directory)/verilator/sim usbtestdata
	$< < usbtestdata
