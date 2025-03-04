typedef int i32;
typedef unsigned char u8;
typedef unsigned int u32;
typedef long long i64;
typedef unsigned long long u64;

#define MCAUSE_ILLEGAL_INSTRUCTION 2
#define MCAUSE_BREAKPOINT 3
#define MCAUSE_ENVIRONMENT_CALL_FROM_M_MODE 11
#define MCAUSE_MACHINE_TIMER_INTERRUPT ((1 << 31) | 7)
#define MCAUSE_MACHINE_EXTERNAL_INTERRUPT ((1 << 31) | 11)

#define PACKET_BUFFER_ADDRESS 0xc0000000
#define CLOCK_FREQUENCY 12000000

void set_timer(u64);
void led_on();
void led_off();

void sleep_for_clock_cycles(int);
void sleep_for_ms(int);

// TODO make this a better API
void enable_external_interrupts();

void clear_usb_interrupt();

void pass();
void fail();

void morse(const char*);
