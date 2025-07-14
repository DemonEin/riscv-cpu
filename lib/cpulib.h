#include <stddef.h>
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

enum led_color {
    LED_COLOR_OFF = 0b000,
    LED_COLOR_RED = 0b001,
    LED_COLOR_GREEN = 0b010,
    LED_COLOR_YELLOW = 0b011,
    LED_COLOR_BLUE = 0b100,
    LED_COLOR_MAGENTA = 0b101,
    LED_COLOR_CYAN = 0b110,
    LED_COLOR_WHITE = 0b111,
};

extern volatile enum led_color led;

void set_timer(uint64_t);
void sleep_for_clock_cycles(uint32_t);
void morse(const char*);

// TODO make this a better API
void enable_external_interrupts();

void clear_usb_interrupt();
void handle_usb_transaction();

void hexdump(const uint8_t*, size_t);

struct ring_buffer {
    const size_t length;
    size_t read_index;
    size_t write_index;
    uint8_t buffer[];
};

// returns the number of bytes read
size_t
ring_buffer_read(volatile struct ring_buffer* ring_buffer, uint8_t* out_buffer, size_t max_size);

// returns the number of bytes written
size_t
ring_buffer_write(volatile struct ring_buffer* ring_buffer, const uint8_t* in_buffer, size_t size);

size_t usb_read(uint8_t* out_buffer, size_t max_size);
