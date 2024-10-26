
string:
.ascii "hello"

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
    # TODO remove when I implement a stall for this
    nop
    bne x1, x2, fail

    # pass test
    ecall

fail:
    ebreak
