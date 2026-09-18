volatile unsigned __int128 kay_dividend;
volatile unsigned __int128 kay_divisor;

void _start(void)
{
    kay_dividend = kay_dividend / kay_divisor;
    for (;;) {
        __asm__ volatile ("hlt");
    }
}
