
#include <stdint.h>

#define MENU_WIDTH  24
#define MENU_HEIGHT 15
#define MENU_ITEMS  (MENU_HEIGHT - 2)   /* rows inside the frame */

struct menu_item {
    uint8_t id;       /* ID */
    char label[13];   /* shown text, up to 12 chars */
    char name[13];    /* 8.3 filename */
};

void print_status(const char *s);
void print_status_arg(const char *s, uint8_t arg);
void menu_draw_frame();
void menu_clean_items();
void menu_draw_items(struct menu_item *items, uint8_t count, uint8_t selected);

