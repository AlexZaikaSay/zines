#include "font.h"
#include "memio.h"
#include "screen.h"
#include <string.h>

uint8_t pos_x = 0;
uint8_t pos_y = 0;

#define MENU_X      ((OSD_VIS_WIDTH - MENU_WIDTH) / 2)
#define MENU_Y      ((OSD_VIS_HEIGHT - MENU_HEIGHT) / 2)


static void posinc(void)
{
    pos_x++;
    if (pos_x >= OSD_VIS_WIDTH)
    {
        pos_x = 0;
        pos_y++;
        if (pos_y >= OSD_VIS_HEIGHT)
        {
            pos_y = 0;
        }
    }
}

void print_status(const char *s)
{
    uint8_t i;
    uint8_t len = strlen(s);
    pos_x = OSD_VIS_WIDTH - len - 1;
    pos_y = OSD_VIS_HEIGHT - 2;
    for (i = 0; i < len; ++i)
    {
        OSD_TEXT[pos_y * OSD_WIDTH + pos_x] = s[i];
        posinc();
    }
}

void print_status_arg(const char *s, uint8_t arg)
{
    static const char hex[] = "0123456789ABCDEF";
    char buf[32];
    uint8_t len;

    /* Keep room for two hex digits and the terminator */
    strncpy(buf, s, sizeof(buf) - 3);
    buf[sizeof(buf) - 3] = '\0';
    len = (uint8_t)strlen(buf);
    buf[len]        = hex[arg >> 4];
    buf[len + 1]    = hex[arg & 0xF];
    buf[len + 2]    = '\0';
    print_status(buf);
}

static void menu_draw_item(uint8_t item, const char *s, uint8_t selected)
{
    /* Inside the frame: one space margin on each side */
    volatile uint8_t *text = &OSD_TEXT[(MENU_Y + 1 + item) * OSD_WIDTH + MENU_X + 2];
    volatile uint8_t *attr = &OSD_ATTR[(MENU_Y + 1 + item) * OSD_WIDTH + MENU_X + 2];
    uint8_t i;

    if (item >= MENU_ITEMS)
    {
        return;
    }
    for (i = 0; i < MENU_WIDTH - 4; ++i)
    {
        if (*s)
        {
            text[i] = *s++;
        }
        else
        {
            text[i] = ' ';
        }
        if (item == selected)
        {
            attr[i] = ATTR(C_WHITE, C_LGRAY) | ATTR_PRESENT;
        }
        else
        {
            attr[i] = ATTR_FG(C_WHITE);
        }
    }
}

void menu_draw_items(struct menu_item *items, uint8_t count, uint8_t selected)
{
    uint8_t i;
    for (i = 0; i < count; ++i)
    {
        menu_draw_item(i, items[i].label, selected);
    }
}

void menu_clean_items()
{
    uint8_t i, j;
    for (i = 0; i < MENU_ITEMS; ++i)
    {
        for (j = 0; j < MENU_WIDTH - 4; ++j)
        {
            OSD_TEXT[(MENU_Y + 1 + i) * OSD_WIDTH + MENU_X + 2 + j] = ' ';
            OSD_ATTR[(MENU_Y + 1 + i) * OSD_WIDTH + MENU_X + 2 + j] = 0;
        }
    }
}

void menu_draw_frame()
{
    uint8_t i;

    OSD_TEXT[MENU_Y * OSD_WIDTH + MENU_X] = BOX2_TL;
    OSD_TEXT[MENU_Y * OSD_WIDTH + (MENU_X + MENU_WIDTH - 1)] = BOX2_TR;
    OSD_TEXT[(MENU_Y + MENU_HEIGHT - 1) * OSD_WIDTH + MENU_X] = BOX2_BL;
    OSD_TEXT[(MENU_Y + MENU_HEIGHT - 1) * OSD_WIDTH + (MENU_X + MENU_WIDTH - 1)] = BOX2_BR;
    for (i = 1; i < MENU_WIDTH - 1; ++i)
    {
        OSD_TEXT[MENU_Y * OSD_WIDTH + (MENU_X + i)] = BOX2_H;
        OSD_TEXT[(MENU_Y + MENU_HEIGHT - 1) * OSD_WIDTH + (MENU_X + i)] = BOX2_H;
    }
    for (i = 1; i < MENU_HEIGHT - 1; ++i)
    {
        OSD_TEXT[(MENU_Y + i) * OSD_WIDTH + MENU_X] = BOX2_V;
        OSD_TEXT[(MENU_Y + i) * OSD_WIDTH + (MENU_X + MENU_WIDTH - 1)] = BOX2_V;
    }
}
