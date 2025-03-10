#include <stdbool.h>

typedef int i32;
typedef unsigned int u32;
typedef long long i64;
typedef unsigned long long u64;

#define MCAUSE_ILLEGAL_INSTRUCTION 2
#define MCAUSE_BREAKPOINT 3
#define MCAUSE_ENVIRONMENT_CALL_FROM_M_MODE 11
#define MCAUSE_MACHINE_TIMER_INTERRUPT ((1 << 31) | 7)
#define MCAUSE_MACHINE_EXTERNAL_INTERRUPT ((1 << 31) | 11)

#define PACKET_BUFFER_ADDRESS 0xc0000000

extern volatile bool led;

void set_timer(u64);

// TODO make this a better API
void enable_external_interrupts();

void clear_usb_interrupt();

void pass();
void fail();
