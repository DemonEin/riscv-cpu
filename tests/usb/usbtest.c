#include "lib/cpulib.h"
#include <assert.h>

int main() {
    __asm__("csrrs zero, mstatus, (1 << 3)"); // set machine interrupt enable bit
    enable_external_interrupts();
    while (1) {
    }
}

[[gnu::interrupt]]
void on_trap() {
    unsigned int mcause;
    __asm__("csrrs %0, mcause, zero" : "=r"(mcause));
    switch (mcause) {
        case MCAUSE_MACHINE_EXTERNAL_INTERRUPT:
            handle_usb_transaction();
            break;
        default:
            assert(false);
    }
}
