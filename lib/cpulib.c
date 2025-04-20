#include "cpulib.h"
#include <stdio.h>

static int __stdout_putc(char c, FILE* file) {
    simulation_putc(c);
    return c;
}

static FILE __stdout = FDEV_SETUP_STREAM(__stdout_putc, nullptr, nullptr, _FDEV_SETUP_WRITE);
FILE* const stdout = &__stdout;

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

void simulation_putc(char c) {
    simulation_print((char[2]) { c, '\0' });
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
