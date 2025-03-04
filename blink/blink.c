#include "lib/cpulib.h"

void wait();

int main() {
    while (1) {
        led_on();
    }

    return 0;
}

[[gnu::interrupt]]
void on_trap() {
    int mcause;
    asm("csrrs %0, mcause, zero" 
            : "=r" (mcause));
    switch (mcause) {
        default:
            fail();
    }
}
