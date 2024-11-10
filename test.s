
string:
.ascii "hello"

.align 4
bad_instruction:
.4byte 0xFFFFFFFF

.align 4
.global _start
_start:
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

unimp_test:
    unimp

    j bad_instruction
return_from_bad_instruction:

    # pass test
    ecall

fail:
    ebreak

.align 4
trap:
    csrrw x1, mcause, x0
    li x2, 2
    beq x1, x2, illegal_instruction
    ebreak
    j return_from_bad_instruction

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
