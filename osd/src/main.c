/* OSD firmware entry point. */

#include "pff.h"
#include "screen.h"
#include "stdio.h"
#include "memio.h"

static FATFS fs;


static struct menu_item games[MENU_ITEMS];
static uint8_t game_count = 0;
static uint8_t game_selected = 0;
static uint8_t game_choosed = 0;

#define OPTIONS_COUNT 5
static struct menu_item options[OPTIONS_COUNT];
static uint8_t option_count = 0;

static uint8_t option_selected = 0;

void fill_game_list(char *filename)
{
    games[game_count].id = game_count;
    strncpy(games[game_count].name, filename, sizeof(games[game_count].name) - 1);
    games[game_count].name[sizeof(games[game_count].name) - 1] = '\0';
    strncpy(games[game_count].label, filename, sizeof(games[game_count].label) - 1);
    games[game_count].label[sizeof(games[game_count].label) - 1] = '\0';
    ++game_count;
}

void fill_options_list(char *filename)
{
    options[option_count].id = option_count;
    strncpy(options[option_count].name, filename, sizeof(options[option_count].name) - 1);
    options[option_count].name[sizeof(options[option_count].name) - 1] = '\0';
    strncpy(options[option_count].label, filename, sizeof(options[option_count].label) - 1);
    options[option_count].label[sizeof(options[option_count].label) - 1] = '\0';
    ++option_count;
}

/* Calls callback for each folder (dirs = 1) or file (dirs = 0) in path */
static void list_dirs(char *path, void (*callback)(char* filename), uint8_t max_count,
                      uint8_t dirs)
{
    FRESULT res;
    uint8_t count = 0;

    DIR dir;
    FILINFO fno;

    res = pf_opendir(&dir, path);
    if (res != FR_OK)
    {
        print_status_arg("OPENDIR ERROR: ", res);
        return;
    }

    
    while (count < max_count)
    {
        res = pf_readdir(&dir, &fno);
        if (res != FR_OK) {
            print_status_arg("READDIR ERROR: ", res);
            break;
        }
        if (fno.fname[0] == '\0')       /* end of directory */
            break;
        if (fno.fattrib & (AM_HID | AM_SYS))
            continue;
        if (((fno.fattrib & AM_DIR) != 0) != dirs)
            continue;
        if (fno.fname[0] == '.')        /* "." and ".." */
            continue;
        
        callback(fno.fname);
        ++count;
    }
}

static void game_up()
{
    if (game_selected > 0)
    {
        --game_selected;
        menu_draw_items(games, game_count, game_selected);
    }
}

static void game_down()
{
    if (game_selected < game_count - 1)
    {
        ++game_selected;
        menu_draw_items(games, game_count, game_selected);
    }
}

static void game_select()
{
    game_choosed = 1;
    option_selected = 0;
    option_count = 0;
    menu_clean_items();
    list_dirs(games[game_selected].name, fill_options_list, OPTIONS_COUNT, 0);
    menu_draw_items(options, option_count, option_selected);
}

static void option_up()
{
    if (option_selected > 0)
    {
        --option_selected;
        menu_draw_items(options, option_count, option_selected);
    }
}

static void option_down()
{
    if (option_selected < option_count - 1)
    {
        ++option_selected;
        menu_draw_items(options, option_count, option_selected);
    }
}

static void option_select()
{
    // Implement the action for selecting an option here
    print_status("Game selected");
}

static void menu_up(void)
{
    if (game_choosed == 0)
    {
        game_up();
    }
    else
    {
        option_up();
    }
}

static void menu_down(void)
{
    if (game_choosed == 0)
    {
        game_down();
    }
    else
    {
        option_down();
    }
}

static void menu_select(void)
{
    if (game_choosed == 0)
    {
        game_select();
    }
    else
    {
        option_select();
    }
}

static void menu_deselect(void)
{
    game_choosed = 0;
    menu_clean_items();
    menu_draw_items(games, game_count, game_selected);
}

int main(void)
{
    FRESULT res;

    res = pf_mount(&fs);
    if (res != FR_OK)
    {
        print_status_arg("SD CARD ERROR: ", res);
        return 1; // Indicate error mounting SD card
    }

    list_dirs("", fill_game_list, MENU_ITEMS, 1);

    if (game_count == 0)
    {
        print_status("SD CARD empty");
        return 1; // Indicate error mounting SD card
    }

    menu_draw_frame();
    menu_draw_items(games, game_count, game_selected);

    for (;;) {
        if (PAD1_PRESSED)
        {
            uint8_t buttons = PAD1;
            if (buttons & BTN_UP)
            {
                menu_up();
            }
            if (buttons & BTN_DOWN)
            {
                menu_down();
            }
            if (buttons & BTN_START || buttons & BTN_SELECT || buttons & BTN_RIGHT)
            {
                menu_select();
            }
            if (buttons & BTN_LEFT)
            {
                menu_deselect();
            }
        }
    }

    return 0;
}
