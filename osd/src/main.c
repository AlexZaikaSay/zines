/* OSD firmware entry point (stub). */

#include "pff.h"

/* Placeholder OSD text buffer; real address comes with the OSD memory map. */
#define OSD_TEXT ((volatile unsigned char *)0x2000)

static FATFS fs;

static void print(const char *s)
{
    unsigned char i;

    for (i = 0; s[i] != '\0'; ++i) {
        OSD_TEXT[i] = s[i];
    }
}

int main(void)
{
    if (pf_mount(&fs) == FR_OK) {
        print("SD CARD OK  ");
    } else {
        print("NO SD CARD  ");
    }

    for (;;) {
    }

    return 0;
}
