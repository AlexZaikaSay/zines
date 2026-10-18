/* OSD firmware entry point (stub). */

#include "pff.h"
#include "memio.h"


static FATFS fs;

uint8_t pos_x = 0;
uint8_t pos_y = 0;

void posinc(void)
{
    pos_x++;
    if (pos_x >= OSD_WIDTH) {
        pos_x = 0;
        pos_y++;
        if (pos_y >= OSD_HEIGHT) {
            pos_y = 0;
        }
    }
}


static void print(const char *s)
{
    unsigned char i;
    for (i = 0; s[i] != '\0'; ++i) {
        OSD_TEXT[pos_y * OSD_WIDTH + pos_x] = s[i];
        posinc();
    }
}

int main(void)
{
    pos_x = 16;
    pos_y = 16;
    print("INIT");
    pos_x = 16;
    pos_y = 17;
    if (pf_mount(&fs) == FR_OK) {
       print("SD CARD OK  ");
    } else {
       print("NO SD CARD  ");
    }

    for (;;) {
    }

    return 0;
}
