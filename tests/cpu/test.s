
string:
.ascii "hello"

.align 4
bad_instruction:
.4byte 0xFFFFFFFF

.align 4
scratch:
.space 128

.align 4
.global main
main:
    lb x1, string + 2
    li x2, 'l'
    bne x1, x2, fail

    li x1, 1
    li x2, 1
    bne x1, x2, fail

    j .+8
    j fail

    li x1, 0
    li x2, 1
    beq x1, x2, fail
    blt x2, x1, fail
    ble x2, x1, fail
    bgt x1, x2, fail
    bge x1, x2, fail

    li x1, 1
    slt x2, x0, x1
    bne x2, x1, fail
    slti x2, x0, 1
    bne x2, x1, fail
    slti x2, x0, 0
    beq x2, x1, fail
    slti x2, x0, -1000
    beq x2, x1, fail
    sltiu x2, x0, -1000
    bne x2, x1, fail
    
    li x1, 1
    li x2, 0
    sw x1, 0(x0)
    lw x2, 0(x0)
    bne x1, x2, fail

    # test non-word-aligned single byte store
    lui t0, %hi(scratch)
    addi t0, a0, %lo(scratch)
    addi t0, t0, 1
    li a0, 57
    sb a0, (t0)
    lbu t1, (t0)
    bne t1, a0, fail

    # test csr's
    li x1, 0
    csrrw x1, misa, x0
    li x2, 0x3FFFFFF # low 26 bits
    and x1, x1, x2
    beq x1, x0, fail

    li x1, 10
    csrrw x0, mscratch, x1
    csrrw x2, mscratch, x0
    bne x1, x2, fail

    li x1, 0
    csrrw x0, mscratch, x1
    li x1, 10
    csrrs x0, mscratch, x1
    csrrw x2, mscratch, x0
    bne x1, x2, fail

    li x1, 0
    csrrw x0, minstreth, x1
    csrrw x0, minstret, x1
    nop
    nop
    nop
    csrrw x1, minstret, x0
    li x2, 3
    bne x1, x2, fail

    li x3, 0
    li x2, 0x80000000
    sw x0, 0(x2)
    # assuming this many nops will increment mtime
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    lw x3, 0(x2)
    beq x0, x3, fail

    lui a0, %hi(trap)
    addi a0, a0, %lo(trap)
    csrrw x0, mtvec, a0

    li x1, 0x80000008 # mtimercmp
    sw zero, 0(x1)
    li x2, 0x8000000c # mtimercmph
    sw zero, 0(x2)
    li x31, 0
    # assume mtime > 0
    # enable all interrupts
    li t0, 0xFFFFFF
    csrrs zero, mie, t0
    li t0, 0b1000
    li t1, 1
    # this should result in a timer interrupt
    csrrs zero, mstatus, t0
    bne x31, t1, fail
    li t0, 0xFFFFFFFF
    csrrc zero, mie, t0

    li sp, 0x69
    li t0, 289
    sw t0, 0(sp)
    li t1, 0
    lw t1, 0(sp)
    bne t0, t1, fail

unimp_test:
    unimp

    j bad_instruction
return_from_bad_instruction:

pass:
    .insn 0x8c000073 # custom instruction to pass test

fail:
    .insn 0xcc000073 # custom instruction to fail test

.align 4
trap:
    csrrw x1, mcause, x0
    li x2, 2
    beq x1, x2, illegal_instruction
    li x2, ((1 << 31) | 7)
    beq x1, x2, timer_interrupt
    j fail

illegal_instruction:
    lui a0, %hi(bad_instruction)
    addi a0, a0, %lo(bad_instruction)
    csrrs a1, mepc, zero
    beq a1, a0, got_bad_instruction

    lui a0, %hi(unimp_test)
    addi a0, a0, %lo(unimp_test)
    beq a1, a0, got_unimp_test

    j fail

got_bad_instruction:
    j return_from_bad_instruction

got_unimp_test:
    csrrw t0, mepc, zero
    addi t0, t0, 4
    csrrw zero, mepc, t0
    mret

timer_interrupt:
    li x31, 1
    li x30, 0xFFFFFFFF
    li x29, 0x8000000c # mtimercmph
    sw x30, 0(x29)
    mret
