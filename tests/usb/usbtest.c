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
            // doing this instead of simulation_printing usb packet buffer directly to
            // cover reading from the usb packet buffer
            for (uint32_t i = 0; usb_packet_buffer[i] != '\0'; i++) {
                simulation_putc(usb_packet_buffer[i]);
            }
            usb_data_length = 0;
            break;
        default:
            fail();
    }
}
