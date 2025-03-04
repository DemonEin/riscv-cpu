
my_led:
.word 0x80000010

test_value:
.word 0x1

.global _start
_start:
    # li sp, 1000



    # li  t0, 1
    # s lli t0, t0, 31
    # ori t0, t0, 16

    # la a0, my_led

    # li a1, 0x588

    # la a0, my_led
    # testing above verifies that the la above is correct
    # lw a0, 0(a0)

    # li a1, 0x80000010
    # li a1, 0x4234

    # bne a0, a1, _start
    # j debug_led_on

    # jal debug_wait
    li t0, 0x80000010
    la a0, my_led
    lw a1, 0(a0)
    sw a1, 0(a0)

    j _start


    li a0, 0x1
    bne a1, a0, _start
    li t1, 1
    sw t1, 0(t0)

    # li t0, 0x80000010

     #li t1, -1
     #sw t1, 0(t0)
    # li t1, 0
    # sw t1, 0(t0)
    # j led_on
    j _start

    # j pass
    lui t0, %hi(on_trap)
    addi t0, t0, %lo(on_trap)
    csrrs zero, mtvec, t0
    j main

lmao:
    ret

debug_led_on:
    li t0, 0x80000010
    li t1, 1
    sw t1, 0(t0)
    ret

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

debug_wait:
    li t0, 12
debug_wait_loop:
    add t0, t0, -1
    bgt t0, zero, debug_wait_loop
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
