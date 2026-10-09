// SDL2 window used by tb_201_video as a live NES display (DPI-C).
#include <SDL.h>

#include <cstdint>
#include <cstdio>

namespace {

constexpr int WIDTH = 256;
constexpr int HEIGHT = 240;
constexpr int SCALE = 3;
constexpr uint32_t FRAME_MS = 1000 / 60;

const uint32_t kPalette[64] = {
    0x666666, 0x002A88, 0x1412A7, 0x3B00A4, 0x5C007E, 0x6E0040, 0x6C0600, 0x561D00,
    0x333500, 0x0B4800, 0x005200, 0x004F08, 0x00404D, 0x000000, 0x000000, 0x000000,
    0xADADAD, 0x155FD9, 0x4240FF, 0x7527FE, 0xA01ACC, 0xB71E7B, 0xB53120, 0x994E00,
    0x6B6D00, 0x388700, 0x0D9300, 0x008F32, 0x007C8D, 0x000000, 0x000000, 0x000000,
    0xFFFEFF, 0x64B0FF, 0x9290FF, 0xC676FF, 0xF36AFF, 0xFE6ECC, 0xFE8170, 0xEA9E22,
    0xBCBE00, 0x88D800, 0x5CE430, 0x45E082, 0x48CDDE, 0x4F4F4F, 0x000000, 0x000000,
    0xFFFEFF, 0xC0DFFF, 0xD3D2FF, 0xE8C8FF, 0xFBC2FF, 0xFEC4EA, 0xFECCC5, 0xF7D8A5,
    0xE4E594, 0xCFEF96, 0xBDF4AB, 0xB3F3CC, 0xB5EBF2, 0xB8B8B8, 0x000000, 0x000000,
};

SDL_Window* window = nullptr;
SDL_Renderer* renderer = nullptr;
SDL_Texture* texture = nullptr;
uint32_t framebuffer[WIDTH * HEIGHT];
uint32_t last_frame_ticks = 0;
uint32_t frame_count = 0;
uint32_t fps_ticks = 0;

}  // namespace

extern "C" {

void sdl_display_init(const char* title) {
    if (window) return;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::fprintf(stderr, "sdl_display: SDL_Init failed: %s\n", SDL_GetError());
        return;
    }
    window = SDL_CreateWindow(title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              WIDTH * SCALE, HEIGHT * SCALE, SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
    if (!window) {
        std::fprintf(stderr, "sdl_display: window failed: %s\n", SDL_GetError());
        return;
    }
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    SDL_RenderSetLogicalSize(renderer, WIDTH, HEIGHT);
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                SDL_TEXTUREACCESS_STREAMING, WIDTH, HEIGHT);
    last_frame_ticks = fps_ticks = SDL_GetTicks();
}

void sdl_display_pixel(int x, int y, int palette_index) {
    if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) return;
    framebuffer[y * WIDTH + x] = 0xFF000000u | kPalette[palette_index & 0x3F];
}

// Shows the finished frame; returns 1 once the user closes the window (or presses Esc).
int sdl_display_present(void) {
    if (!window) return 1;

    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) return 1;
        if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) return 1;
    }

    SDL_UpdateTexture(texture, nullptr, framebuffer, WIDTH * sizeof(uint32_t));
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, nullptr, nullptr);
    SDL_RenderPresent(renderer);

    // Cap at 60 fps; a slower simulation simply runs below real time.
    uint32_t now = SDL_GetTicks();
    if (now - last_frame_ticks < FRAME_MS) SDL_Delay(FRAME_MS - (now - last_frame_ticks));
    last_frame_ticks = SDL_GetTicks();

    if (++frame_count % 30 == 0) {
        uint32_t t = SDL_GetTicks();
        char title[64];
        std::snprintf(title, sizeof(title), "zines NES - %.1f fps",
                      30000.0 / (t - fps_ticks));
        SDL_SetWindowTitle(window, title);
        fps_ticks = t;
    }
    return 0;
}

void sdl_display_close(void) {
    if (texture) SDL_DestroyTexture(texture);
    if (renderer) SDL_DestroyRenderer(renderer);
    if (window) SDL_DestroyWindow(window);
    texture = nullptr;
    renderer = nullptr;
    window = nullptr;
    SDL_Quit();
}

}  // extern "C"
