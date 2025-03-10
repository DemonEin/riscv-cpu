#include "lib/cpulib.h"

void wait();

int main() {
    while (1) {
        led = true;
        wait();
        led = false;
        wait();
    }

    return 0;
}
