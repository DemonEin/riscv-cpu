#include "cpulib.h"
#include <stdio.h>

static int __stdout_putc(char c, FILE* file) {
#ifdef SIMULATION
    simulation_putchar(c);
#endif
    return c;
}

#define STDERR_BUFFER_LENGTH 32
static char stderr_buffer[STDERR_BUFFER_LENGTH];
static size_t stderr_buffer_index = 0;

static int __stderr_putc(char c, FILE* file) {
#ifdef SIMULATION
    simulation_putchar(c);
    return c;
#else
    // - 1 to make sure there is a trailing null char
    if (stderr_buffer_index < STDERR_BUFFER_LENGTH - 1) {
        stderr_buffer[stderr_buffer_index] = c;
        stderr_buffer_index++;
        return c;
    } else {
        // doesn't set the error indicator on the file, whatever
        return EOF;
    }
#endif
}

static FILE __stdout = FDEV_SETUP_STREAM(__stdout_putc, nullptr, nullptr, _FDEV_SETUP_WRITE);
static FILE __stderr = FDEV_SETUP_STREAM(__stderr_putc, nullptr, nullptr, _FDEV_SETUP_WRITE);
FILE* const stdout = &__stdout;
FILE* const stderr = &__stderr;

void _exit() {
#ifdef SIMULATION
    simulation_fail();
#else
    morse(stderr_buffer);
#endif
}

volatile uint64_t* timer_cmp = (uint64_t*)0x80000000 + 8;

void set_timer(uint64_t time) {
    *timer_cmp = *timer_cmp + time;
    int set_val = 1 << 7;
    __asm__("csrrs zero, mie, %0" : : "r"(set_val));
    set_val = 1 << 3;
    __asm__("csrrs zero, mstatus, %0" : : "r"(set_val));
}

void sleep_ms(uint32_t time) {
    sleep_for_clock_cycles(time * (CLOCK_FREQUENCY / 1000));
}

static char nibble_to_hex(uint8_t byte) {
    const uint8_t nibble = byte & 0xf;
    if (nibble < 10) {
        return '0' + nibble;
    } else {
        return (nibble - 10) + 'a';
    }
}

void hexdump(const uint8_t* buffer, size_t length) {
    for (size_t i = 0; i < length; i++) {
        const uint8_t byte = buffer[i];
        putchar('0');
        putchar('x');
        putchar(nibble_to_hex(byte >> 4));
        putchar(nibble_to_hex(byte));
        if (!(i == length - 1)) {
            putchar(' ');
        }
    }
    putchar('\n');
}

// read_index is the next index to read data from
// write_index is the next index to write data to
// when read_index == write_index there is no data to read
// when write_index is one position before read_index the buffer is full

size_t
ring_buffer_read(volatile struct ring_buffer* ring_buffer, uint8_t* out_buffer, size_t size) {
    const size_t length = ring_buffer->length;
    size_t read_index = ring_buffer->read_index;
    volatile uint8_t* buffer = ring_buffer->buffer;
    // this one is at the end to give as much time as possible for there to be more data
    const size_t write_index = ring_buffer->write_index;

    size_t bytes_read = 0;
    while (read_index != write_index && bytes_read < size) {
        out_buffer[bytes_read] = buffer[read_index];

        read_index++;
        if (read_index >= length) {
            read_index = 0;
        }
        bytes_read++;
    }

    ring_buffer->read_index = read_index;
    return bytes_read;
}

size_t
ring_buffer_write(volatile struct ring_buffer* ring_buffer, const uint8_t* in_buffer, size_t size) {
    const size_t length = ring_buffer->length;
    size_t write_index = ring_buffer->write_index;
    volatile uint8_t* buffer = ring_buffer->buffer;
    // this one is at the end to give as much time as possible for data to be read
    const size_t read_index = ring_buffer->read_index;

    size_t bytes_written = 0;
    size_t next_write_index = write_index + 1;
    if (next_write_index >= length) {
        next_write_index = 0;
    }
    while (next_write_index != read_index && bytes_written < size) {
        buffer[write_index] = in_buffer[bytes_written];

        write_index++;
        if (write_index >= length) {
            write_index = 0;
        }
        next_write_index = write_index + 1;
        if (next_write_index >= length) {
            next_write_index = 0;
        }

        bytes_written++;
    }

    ring_buffer->write_index = write_index;
    return bytes_written;
}

extern volatile struct bulk_read_ring_buffer* bulk_read_ring_buffer;

size_t usb_read(uint8_t* out_buffer, size_t max_size) {
    return ring_buffer_read(
        (volatile struct ring_buffer*)&bulk_read_ring_buffer,
        out_buffer,
        max_size
    );
}

#define MORSE_TIME_UNIT 200 // in ms

void morse_sleep(uint32_t time_units) {
    sleep_ms(MORSE_TIME_UNIT * time_units);
}

void morse_short() {
    led = true;
    morse_sleep(1);
    led = false;
    morse_sleep(1);
}

void morse_long() {
    led = true;
    morse_sleep(3);
    led = false;
    morse_sleep(1);
}

void blink_morse(const char* message) {
    for (char c; (c = *message) != '\0'; message++) {
        // make c lowercase
        if (c >= 'A' && c <= 'Z') {
            c += 'a' - 'A';
        }

        bool got_character = true;

        switch (c) {
            case 'a':
                morse_short();
                morse_long();
                break;
            case 'b':
                morse_long();
                morse_short();
                morse_short();
                morse_short();
                break;
            case 'c':
                morse_long();
                morse_short();
                morse_long();
                morse_short();
                break;
            case 'd':
                morse_long();
                morse_short();
                morse_short();
                break;
            case 'e':
                morse_short();
                break;
            case 'f':
                morse_short();
                morse_short();
                morse_long();
                morse_short();
                break;
            case 'g':
                morse_long();
                morse_long();
                morse_short();
                break;
            case 'h':
                morse_short();
                morse_short();
                morse_short();
                morse_short();
                break;
            case 'i':
                morse_short();
                morse_short();
                break;
            case 'j':
                morse_short();
                morse_long();
                morse_long();
                morse_long();
                break;
            case 'k':
                morse_long();
                morse_short();
                morse_long();
                break;
            case 'l':
                morse_short();
                morse_long();
                morse_short();
                morse_short();
                break;
            case 'm':
                morse_long();
                morse_long();
                break;
            case 'n':
                morse_long();
                morse_short();
                break;
            case 'o':
                morse_long();
                morse_long();
                morse_long();
                break;
            case 'p':
                morse_short();
                morse_long();
                morse_long();
                morse_short();
                break;
            case 'q':
                morse_long();
                morse_long();
                morse_short();
                morse_long();
                break;
            case 'r':
                morse_short();
                morse_long();
                morse_short();
                break;
            case 's':
                morse_short();
                morse_short();
                morse_short();
                break;
            case 't':
                morse_long();
                break;
            case 'u':
                morse_short();
                morse_short();
                morse_long();
                break;
            case 'v':
                morse_short();
                morse_short();
                morse_short();
                morse_long();
                break;
            case 'w':
                morse_short();
                morse_long();
                morse_long();
                break;
            case 'x':
                morse_long();
                morse_short();
                morse_short();
                morse_long();
                break;
            case 'y':
                morse_long();
                morse_short();
                morse_long();
                morse_long();
                break;
            case 'z':
                morse_short();
                morse_short();
                morse_short();
                morse_long();
                break;
            case '0':
                morse_long();
                morse_long();
                morse_long();
                morse_long();
                morse_long();
                break;
            case '1':
                morse_short();
                morse_long();
                morse_long();
                morse_long();
                morse_long();
                break;
            case '2':
                morse_short();
                morse_short();
                morse_long();
                morse_long();
                morse_long();
                break;
            case '3':
                morse_short();
                morse_short();
                morse_short();
                morse_long();
                morse_long();
                break;
            case '4':
                morse_short();
                morse_short();
                morse_short();
                morse_short();
                morse_long();
                break;
            case '5':
                morse_short();
                morse_short();
                morse_short();
                morse_short();
                morse_short();
                break;
            case '6':
                morse_long();
                morse_short();
                morse_short();
                morse_short();
                morse_short();
                break;
            case '7':
                morse_long();
                morse_long();
                morse_short();
                morse_short();
                morse_short();
                break;
            case '8':
                morse_long();
                morse_long();
                morse_long();
                morse_short();
                morse_short();
                break;
            case '9':
                morse_long();
                morse_long();
                morse_long();
                morse_long();
                morse_short();
                break;
            case ' ':
                morse_sleep(5); // two time units will be done at the end of the loop
                break;
            default:
                got_character = false;
        }

        if (got_character) {
            morse_sleep(2); // one time unit was already slept for as part of the last element
        }
    }
}

// diverges, ideally this would be asynchronous but this is sufficient for fatal errors
void morse(const char* message) {
    while (true) {
        led = false;
        morse_sleep(10);
        led = true;
        morse_sleep(10);
        led = false;
        morse_sleep(10);
        blink_morse(message);
    }
}
