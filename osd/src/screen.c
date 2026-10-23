#include "font.h"
#include "memio.h"
#include "screen.h"

uint8_t pos_x = 0;
uint8_t pos_y = 0;

#define MENU_X      ((OSD_VIS_WIDTH - MENU_WIDTH) / 2)
#define MENU_Y      ((OSD_VIS_HEIGHT - MENU_HEIGHT) / 2)

#define MENU_BUF_WIDTH 13
static char menu_names[MENU_ITEMS][MENU_BUF_WIDTH];
static uint8_t menu_size = 0;

static uint8_t menu_selected = 0;

static uint8_t strlen(const char *s)
{
    uint8_t len = 0;
    while (s[len] != '\0')
    {
        len++;
    }
    return len;
}


static uint8_t strncpy(char *dest, const char *src, uint8_t n)
{
    uint8_t i = 0;
    while (src[i] != '\0' && i < n)
    {
        dest[i] = src[i];
        i++;
    }
    if (i < n)
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
    uint8_t len = strncpy(buf, s, 32);
    buf[len]        = hex[arg >> 4];
    buf[len + 1]    = hex[arg & 0xF];
    buf[len + 2]    = '\0';
    print_status(buf);
}

static void menu_draw_item(uint8_t item, const char *s)
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
        if (item == menu_selected)
        {
            attr[i] = ATTR(C_WHITE, C_LGRAY) | ATTR_PRESENT;
        }
        else
        {
            attr[i] = ATTR_FG(C_WHITE);
        }
    }
}

static void menu_draw_all_items(void)
{
    uint8_t i;
    for (i = 0; i < menu_size; ++i)
    {
        menu_draw_item(i, menu_names[i]);
    }
}

void menu_draw(void)
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

    menu_draw_all_items();
}

void menu_add_item(const char *s)
{
    if (menu_size >= MENU_ITEMS)
        return;
    strncpy(menu_names[menu_size], s, MENU_BUF_WIDTH - 1);
    menu_names[menu_size][MENU_BUF_WIDTH - 1] = '\0';
    ++menu_size;
}

void menu_up()
{
    if (menu_selected > 0)
    {
        --menu_selected;
        menu_draw_all_items();
    }
}

void menu_down()
{
    if (menu_selected < menu_size - 1)
    {
        ++menu_selected;
        menu_draw_all_items();
    }
}

void menu_select()
{
    // Implement menu select action here
}
