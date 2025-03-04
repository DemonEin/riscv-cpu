.global wait
wait:
    li t0, 1
wait_loop:
    add t0, t0, -1
    bgt t0, zero, wait_loop
    ret
