.global _start
_start:
    li sp, 0x3ff0 # must have 128 bit alignment at procedure entry according to ABI
    lui t0, %hi(on_trap)
    addi t0, t0, %lo(on_trap)
    csrrs zero, mtvec, t0
    j main

.weak on_trap
on_trap:
    mret

.global sleep_for_clock_cycles
sleep_for_clock_cycles:
    srai a0, a0, 1 # divide by two since the loop is two instructions
    addi a0, a0, -2 # subtract by two to compensate for the four other instructions
    nop
sleep_for_clock_cycles_loop:
    addi a0, a0, -1
    bgt a0, zero, sleep_for_clock_cycles_loop
    ret

.global pass
pass:
    .insn 0x8c000073 # custom instruction to pass test

.global fail
fail:
    .insn 0xcc000073 # custom instruction to fail test

.global simulation_print
simulation_print:
    .insn 0x0c000073 # custom instruction to print string starting at a0
    ret

.global enable_external_interrupts
enable_external_interrupts:
    li t0, (1 << 11)
    csrrw zero, mie, t0
    ret
