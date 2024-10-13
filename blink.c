void wait();
void on();
void off();

int _start() {
    
    while (1) {
        on();
        wait();
        off();
        wait();
    }

    return 0;
}
