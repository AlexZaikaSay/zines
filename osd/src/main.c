/* OSD firmware entry point. */

#include "memio.h"
#include "nes.h"
#include "pff.h"
#include "screen.h"
#include <string.h>


static FATFS fs;


static struct menu_item games[MENU_ITEMS];
static uint8_t game_count = 0;
static uint8_t game_selected = 0;
static uint8_t game_choosed = 0;

#define OPTIONS_COUNT 5
static struct menu_item options[OPTIONS_COUNT];
static uint8_t option_count = 0;

static uint8_t option_selected = 0;
static uint8_t game_running = 0;   /* a game was started: the menu is hidden */

/* In-game menu, opened by pressing Start + Select */
enum
{
    PAUSE_RESUME,
    PAUSE_SAVE,
    PAUSE_LOAD,
    PAUSE_QUIT,
    PAUSE_COUNT
};
static struct menu_item pause_items[PAUSE_COUNT];

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
    uint8_t res;
    // Implement the action for selecting an option here
    
    res = load_nes(games[game_selected].name, options[0].name, options[option_selected].name);
    if (res != 0)
    {
        print_status_arg("LOAD NES ERROR: ", res);
        return;
    }
    game_running = 1;
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

static void set_item(struct menu_item *item, uint8_t id, const char *label)
{
    item->id = id;
    strncpy(item->label, label, sizeof(item->label) - 1);
    item->label[sizeof(item->label) - 1] = '\0';
    item->name[0] = '\0';
}

/* Waits until no button is down, so a button still held from the menu
 * does not reach the game (or the next menu). */
static void wait_release(void)
{
    while (PAD1 != 0)
    {
    }
}

static void show_game_list(void)
{
    game_choosed = 0;
    screen_clear();
    menu_draw_frame();
    menu_draw_items(games, game_count, game_selected);
}

/* Pauses the game and runs the in-game menu until the game is resumed or quit. */
static void pause_menu(void)
{
    uint8_t selected = PAUSE_RESUME;
    uint8_t buttons;

    nes_pause();

    set_item(&pause_items[PAUSE_RESUME], PAUSE_RESUME, "RESUME");
    set_item(&pause_items[PAUSE_SAVE], PAUSE_SAVE, "SAVE STATE");
    set_item(&pause_items[PAUSE_LOAD], PAUSE_LOAD, "LOAD STATE");
    set_item(&pause_items[PAUSE_QUIT], PAUSE_QUIT, "QUIT");
    menu_draw_frame();
    menu_draw_items(pause_items, PAUSE_COUNT, selected);

    wait_release();             /* Start + Select may still be held */

    for (;;)
    {
        if (!PAD1_PRESSED)
        {
            continue;
        }
        buttons = PAD1;
        if ((buttons & BTN_UP) && selected > 0)
        {
            --selected;
            menu_draw_items(pause_items, PAUSE_COUNT, selected);
        }
        if ((buttons & BTN_DOWN) && selected < PAUSE_COUNT - 1)
        {
            ++selected;
            menu_draw_items(pause_items, PAUSE_COUNT, selected);
        }
        if (buttons & BTN_B)
        {
            selected = PAUSE_RESUME;    /* B: back to the game */
        }
        else if ((buttons & (BTN_A | BTN_START)) == 0)
        {
            continue;
        }

        switch (selected)
        {
            case PAUSE_RESUME:
                wait_release();
                screen_clear();
                nes_resume();       /* last: the simulation stops the supervisor clock here */
                return;
            case PAUSE_QUIT:
                NES_CTRL = NES_RESET;
                game_running = 0;
                wait_release();
                show_game_list();
                return;
            default:
                print_status("NOT IMPLEMENTED");
                break;
        }
    }
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
        if (game_running)
        {
            if (SYS_STATUS & ST_HOTKEY)
            {
                pause_menu();
            }
        }
        else if (PAD1_PRESSED)
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
