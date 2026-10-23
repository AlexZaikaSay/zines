
#include <stdint.h>

#define MENU_WIDTH  24
#define MENU_HEIGHT 15
#define MENU_ITEMS  (MENU_HEIGHT - 2)   /* rows inside the frame */

void print_status(const char *s);
void print_status_arg(const char *s, uint8_t arg);
void menu_draw(void);
void menu_up(void);
void menu_down(void);
void menu_select(void);
void menu_add_item(const char *s);