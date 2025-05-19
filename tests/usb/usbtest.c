#include "lib/cpulib.h"
#include <assert.h>

int main() {
    __asm__("csrrs zero, mstatus, (1 << 3)"); // set machine interrupt enable bit
    enable_external_interrupts();
    while (1) {
        uint8_t read_buffer[1];
        size_t bytes_read = usb_read(read_buffer, 1);
        if (bytes_read > 0) {
            led = !led;
        }
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
