export program_files = blink/blink.s blink/blink.c

.PHONY: sim
sim:
	make -C ../ sim target_directory=target/blink

.PHONY: install
install:
	make -C ../ install target_directory=target/blink
