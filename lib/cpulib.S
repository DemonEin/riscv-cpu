.global _start
_start:
    li sp, 0xfff0 # must have 128 bit alignment at procedure entry according to ABI
    lui t0, %hi(on_trap)
    addi t0, t0, %lo(on_trap)
    csrrs zero, mtvec, t0

    # enable external interrupts
    li t0, (1 << 11)
    csrrs zero, mie, t0

    csrrs zero, mstatus, (1 << 3) # enable machine interrupts

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

#ifdef SIMULATION

.global simulation_putchar
simulation_putchar:
    .insn 0x0c000073 # custom instruction to write one char to stdout
    ret

#endif
