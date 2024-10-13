.global on
on:
    li t0, 1
    sw t0, 0(x0)
    ret

.global off
off:
    li t0, 0
    sw t0, 0(x0)
    ret

.global wait
wait:
    li t0, 12000000
wait_loop:
    add t0, t0, -1
    bgt t0, zero, wait_loop
    ret
