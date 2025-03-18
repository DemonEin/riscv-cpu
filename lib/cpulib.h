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

#define MCAUSE_ILLEGAL_INSTRUCTION 2
#define MCAUSE_BREAKPOINT 3
#define MCAUSE_ENVIRONMENT_CALL_FROM_M_MODE 11
#define MCAUSE_MACHINE_TIMER_INTERRUPT ((1 << 31) | 7)
#define MCAUSE_MACHINE_EXTERNAL_INTERRUPT ((1 << 31) | 11)

#define PACKET_BUFFER_ADDRESS 0xc0000000

extern volatile bool led;

void set_timer(uint64_t);
void sleep_for_clock_cycles(uint32_t);
void morse(const char*);

// TODO make this a better API
void enable_external_interrupts();

void clear_usb_interrupt();

void pass();
void fail();
void simulation_print(const char*);
