#include "lib/cpulib.h"

void wait();

int main() {
    while (1) {
        led_on();
        wait();
        led_off();
        wait();
    }

    return 0;
}
