extern long write(int descriptor, const void *buffer, unsigned long count);

static const char message[] = "host dependency";

void _start(void)
{
    (void)write(1, message, sizeof(message));
    for (;;) {
        __asm__ volatile ("hlt");
    }
}
