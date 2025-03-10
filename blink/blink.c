#include "lib/cpulib.h"

void wait();

int main() {
    morse("ieianfie");
    while (1) {}
    while (1) {
        led = true;
        wait();
        led = false;
        wait();
    }

    return 0;
}
