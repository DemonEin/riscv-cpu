A RISC-V CPU implementing the RV32I base instruction set, Zicsr extension, and
machine mode privileged architecture designed to run on the Lattice ECP5
LFE5U-85 FPGA on the [OrangeCrab development board](
https://orangecrab-fpga.github.io/orangecrab-hardware/).

## Build

There are different example programs to run, each in their own directory. All
require, for both simulation and running on hardware:

* A GCC toolchain targeting riscv32
* The latest stable Rust toolchain

### Simulation

The CPU can be simulated using [verilator](
https://www.veripool.org/verilator/). To simulate the CPU with an example
program, run `make sim` from that example program's directory. For example,
to simulate the CPU with the blink program, run
```
make -C blink sim
```
from the top repository directory.

### Running on Hardware

Building and installing to an OrangeCrab development board requires several
dependencies:
* [yosys](https://github.com/YosysHQ/yosys) - nightly version required
* [nextpnr-ecp5](https://github.com/YosysHQ/nextpnr) - nightly version required
* [dfu-util](https://dfu-util.sourceforge.net)

With the OrangeCrab board plugged in via USB, run `make sim` from an example
program's directory. For example, to run the blink program on the hardware, run
```
make -C blink install
```
from the top repository directory.

### Tests

Tests run as simulations, so running tests has the same requirements as running
simulations. Run tests with the test script:
```
./test.sh
```
