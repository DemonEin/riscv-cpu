#include "lib/cpulib.h"
#include <assert.h>
#include <string.h>

int main() {
    __asm__("csrrs zero, mstatus, (1 << 3)"); // set machine interrupt enable bit
    enable_external_interrupts();
    while (1) {
        uint8_t read_buffer[32];
        size_t bytes_read = usb_read(read_buffer, 32);
        if (bytes_read > 0) {
            if (strncmp((char*)read_buffer, "red\n", bytes_read) == 0) {
                led = LED_COLOR_RED;
            } else if (strncmp((char*)read_buffer, "green\n", bytes_read) == 0) {
                led = LED_COLOR_GREEN;
            } else if (strncmp((char*)read_buffer, "yellow\n", bytes_read) == 0) {
                led = LED_COLOR_YELLOW;
            } else if (strncmp((char*)read_buffer, "blue\n", bytes_read) == 0) {
                led = LED_COLOR_BLUE;
            } else if (strncmp((char*)read_buffer, "magenta\n", bytes_read) == 0) {
                led = LED_COLOR_MAGENTA;
            } else if (strncmp((char*)read_buffer, "cyan\n", bytes_read) == 0) {
                led = LED_COLOR_CYAN;
            } else if (strncmp((char*)read_buffer, "white\n", bytes_read) == 0) {
                led = LED_COLOR_WHITE;
            } else if (strncmp((char*)read_buffer, "off\n", bytes_read) == 0) {
                led = LED_COLOR_OFF;
            }
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
