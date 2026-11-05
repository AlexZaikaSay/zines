// SDL stand-ins for the PGO training run (pgo_main.cpp): no window, no sound.
// sdl_display_present is called once per display frame in the menu; Start is
// held for a few of them twice: first game folder, then its ROM file.
static int presents = 0;

extern "C" {
void sdl_display_init(const char*) {}
void sdl_display_pixel(int, int, int) {}
void sdl_display_osd_pixel(int, int, int) {}
int  sdl_display_present(void) { ++presents; return 0; }
void sdl_display_close(void) {}
int  sdl_display_buttons(void) {
    return ((presents >= 10 && presents < 14) || (presents >= 30 && presents < 34)) ? 0x08 : 0;
}
void sdl_audio_init(void) {}
void sdl_audio_sample(int, int, int, int) {}
void sdl_audio_close(void) {}
}
