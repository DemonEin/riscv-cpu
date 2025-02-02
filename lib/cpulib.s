.global _start
_start:
    li sp, 1000
    lui t0, %hi(on_trap)
    addi t0, t0, %lo(on_trap)
    csrrs zero, mtvec, t0
    j main

.weak on_trap
on_trap:
    mret

.global sleep_for_clock_cycles
wait:
    li t0, 12000000
wait_loop:
    add t0, t0, -1
    bgt t0, zero, wait_loop
    ret

.global clear_usb_interrupt
clear_usb_interrupt:
    .insn 0xec000073 # custom instruction
    ret

.global pass
pass:
    .insn 0x8c000073 # custom instruction to pass test

.global fail
fail:
    .insn 0xcc000073 # custom instruction to fail test

.global enable_external_interrupts
enable_external_interrupts:
    li t0, (1 << 11)
    csrrw zero, mie, t0
    ret
