/* OSD firmware entry point (stub). */

/* Placeholder OSD text buffer; real address comes with the OSD memory map. */
#define OSD_TEXT ((volatile unsigned char *)0x2000)

static const char hello[] = "HELLO, WORLD";

int main(void)
{
    unsigned char i;

    for (i = 0; hello[i] != '\0'; ++i) {
        OSD_TEXT[i] = hello[i];
    }

    for (;;) {
    }

    return 0;
}
