#include "font.h"
#include "memio.h"
#include "screen.h"

uint8_t pos_x = 0;
uint8_t pos_y = 0;

#define MENU_WIDTH  24
#define MENU_HEIGHT 15

static uint8_t strlen(const char *s)
{
    uint8_t len = 0;
    while (s[len] != '\0') {
        len++;
    }
    return len;
}

static void posinc(void)
{
    pos_x++;
    if (pos_x >= OSD_VIS_WIDTH) {
        pos_x = 0;
        pos_y++;
        if (pos_y >= OSD_VIS_HEIGHT) {
            pos_y = 0;
        }
    }
}

void printstatus(const char *s)
{
    uint8_t i;
    uint8_t len = strlen(s);
    pos_x = OSD_VIS_WIDTH - len - 1;
    pos_y = OSD_VIS_HEIGHT - 2;
    for (i = 0; i < len; ++i) {
        OSD_TEXT[pos_y * OSD_WIDTH + pos_x] = s[i];
        posinc();
    }
}

void draw_menu(void)
{
    uint8_t x, y;
    uint8_t start_x = (OSD_VIS_WIDTH - MENU_WIDTH) / 2;
    uint8_t start_y = (OSD_VIS_HEIGHT - MENU_HEIGHT) / 2;

    OSD_TEXT[start_y * OSD_WIDTH + start_x] = BOX2_TL;
    OSD_TEXT[start_y * OSD_WIDTH + (start_x + MENU_WIDTH - 1)] = BOX2_TR;
    OSD_TEXT[(start_y + MENU_HEIGHT - 1) * OSD_WIDTH + start_x] = BOX2_BL;
    OSD_TEXT[(start_y + MENU_HEIGHT - 1) * OSD_WIDTH + (start_x + MENU_WIDTH - 1)] = BOX2_BR;
    for (x = 1; x < MENU_WIDTH - 1; ++x)
    {
        OSD_TEXT[start_y * OSD_WIDTH + (start_x + x)] = BOX2_H;
        OSD_TEXT[(start_y + MENU_HEIGHT - 1) * OSD_WIDTH + (start_x + x)] = BOX2_H;
    }
    for (y = 1; y < MENU_HEIGHT - 1; ++y)
    {
        OSD_TEXT[(start_y + y) * OSD_WIDTH + start_x] = BOX2_V;
        OSD_TEXT[(start_y + y) * OSD_WIDTH + (start_x + MENU_WIDTH - 1)] = BOX2_V;
    }
}
