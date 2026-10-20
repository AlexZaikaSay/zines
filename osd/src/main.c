/* OSD firmware entry point (stub). */

#include "pff.h"
#include "screen.h"

static FATFS fs;


int main(void)
{
    draw_menu();

    if (pf_mount(&fs) == FR_OK)
    {
       //printstatus("SD CARD OK");
    }
    else
    {
        //printstatus("NO SD CARD");
    }

    for (;;) {
    }

    return 0;
}
