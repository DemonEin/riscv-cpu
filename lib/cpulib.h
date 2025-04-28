#include <stdint.h>

#define CLOCK_FREQUENCY 12000000

#ifdef SIMULATION
    #define simulation_pass() __asm__(".insn 0x8c000073"); // custom instruction to pass test
    #define simulation_fail() __asm__(".insn 0xcc000073"); // custon instruction to fail test

void simulation_putchar(char);
#endif

enum mcause {
    MCAUSE_ILLEGAL_INSTRUCTION = 2,
    MCAUSE_BREAKPOINT = 3,
    MCAUSE_ENVIRONMENT_CALL_FROM_M_MODE = 11,
    MCAUSE_MACHINE_TIMER_INTERRUPT = 0x80000007,
    MCAUSE_MACHINE_EXTERNAL_INTERRUPT = 0x8000000b,
};

extern volatile bool led;

void set_timer(uint64_t);
void sleep_for_clock_cycles(uint32_t);
void morse(const char*);

// TODO make this a better API
void enable_external_interrupts();

void clear_usb_interrupt();
void handle_usb_transaction();
