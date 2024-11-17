typedef int i32;
typedef unsigned int u32;
typedef long long i64;
typedef unsigned long long u64;

#define MCAUSE_ILLEGAL_INSTRUCTION 2
#define MCAUSE_BREAKPOINT 3
#define MCAUSE_ENVIRONMENT_CALL_FROM_M_MODE 11
#define MCAUSE_MACHINE_TIMER_INTERRUPT ((1 << 31) | 7)

void set_timer(u64);
void led_on();
void led_off();

void pass();
void fail();
