/* OSD firmware entry point. */

#include "pff.h"
#include "screen.h"

static FATFS fs;
static DIR dir;
static FILINFO fno;

/* List the folders in the root directory as menu items; returns the count */
static uint8_t list_root_dirs(void)
{
    uint8_t count = 0;
    FRESULT res;

    res = pf_opendir(&dir, "");
    if (res != FR_OK) {
        print_status_arg("OPENDIR ERROR: ", res);
        return 0;
    }

    while (count < MENU_ITEMS) {
        res = pf_readdir(&dir, &fno);
        if (res != FR_OK) {
            print_status_arg("READDIR ERROR: ", res);
            break;
        }
        if (fno.fname[0] == '\0')       /* end of directory */
            break;
        if (!(fno.fattrib & AM_DIR) || (fno.fattrib & (AM_HID | AM_SYS)))
            continue;
        if (fno.fname[0] == '.')        /* "." and ".." */
            continue;
        add_menu_item(fno.fname);
        ++count;
    }
    return count;
}

int main(void)
{
    FRESULT res;

    res = pf_mount(&fs);
    if (res != FR_OK)
    {
        print_status_arg("SD CARD ERROR: ", res);
    }
    else if (list_root_dirs() == 0)
    {
        add_menu_item("NO FOLDERS");
    }

    draw_menu();

    for (;;) {
    }

    return 0;
}
