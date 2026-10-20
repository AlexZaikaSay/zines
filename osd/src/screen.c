#include "font.h"
#include "memio.h"
#include "screen.h"

uint8_t pos_x = 0;
uint8_t pos_y = 0;

#define MENU_X      ((OSD_VIS_WIDTH - MENU_WIDTH) / 2)
#define MENU_Y      ((OSD_VIS_HEIGHT - MENU_HEIGHT) / 2)

static uint8_t strlen(const char *s)
{
    uint8_t len = 0;
    while (s[len] != '\0')
    {
        len++;
    }
    return len;
}

static uint8_t strdup(char *dest, const char *src)
{
    uint8_t i = 0;
    while (src[i] != '\0')
    {
        dest[i] = src[i];
        i++;
    }
    dest[i] = '\0';
    return i;
}

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
    uint8_t len = strdup(buf, s);
    buf[len]        = hex[arg >> 4];
    buf[len + 1]    = hex[arg & 0xF];
    buf[len + 2]    = '\0';
    print_status(buf);
}

void draw_menu(void)
{
    uint8_t x, y;
    uint8_t start_x = MENU_X;
    uint8_t start_y = MENU_Y;

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

void menu_item(uint8_t row, const char *s)
{
    /* Inside the frame: one space margin on each side */
    volatile uint8_t *p = &OSD_TEXT[(MENU_Y + 1 + row) * OSD_WIDTH + MENU_X + 2];
    uint8_t i;

    if (row >= MENU_ITEMS)
        return;
    for (i = 0; i < MENU_WIDTH - 4; ++i)
    {
        if (*s)
            p[i] = *s++;
        else
            p[i] = ' ';
    }
}
