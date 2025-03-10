#include "cpulib.h"
#include "stdbool.h"

volatile u64* timer_cmp = (u64*) 0x80000000 + 8;

void set_timer(u64 time) {
    *timer_cmp = *timer_cmp + time;
    int set_val = 1 << 7;
    asm("csrrs zero, mie, %0" : : "r" (set_val));
    set_val = 1 << 3;
    asm("csrrs zero, mstatus, %0" : : "r" (set_val));
}
