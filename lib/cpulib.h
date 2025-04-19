#include <stdbool.h>

// using ILP32 convention
typedef signed char int8_t;
typedef short int16_t;
typedef int int32_t;
typedef long long int64_t;

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

#define CLOCK_FREQUENCY 12000000

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

void pass();
void fail();
void simulation_print(const char*);
void simulation_putc(char);
