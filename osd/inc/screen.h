
#include <stdint.h>

#define MENU_WIDTH  24
#define MENU_HEIGHT 15
#define MENU_ITEMS  (MENU_HEIGHT - 2)   /* rows inside the frame */

void print_status(const char *s);
void print_status_arg(const char *s, uint8_t arg);
void draw_menu(void);
/* Write s on menu line row (0..MENU_ITEMS-1), padded with spaces */
void add_menu_item(const char *s);