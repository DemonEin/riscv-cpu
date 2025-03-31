#include "lib/cpulib.h"

int main() {
    asm("csrrs zero, mstatus, (1 << 3)"); // set machine interrupt enable bit
    enable_external_interrupts();
    while (1) {
    }
}

[[gnu::interrupt]]
void on_trap() {
    int mcause;
    asm("csrrs %0, mcause, zero" 
            : "=r" (mcause));
    switch (mcause) {
        case MCAUSE_MACHINE_EXTERNAL_INTERRUPT:
            handle_usb_transaction();
            break;
        default:
            fail();
    }
}
