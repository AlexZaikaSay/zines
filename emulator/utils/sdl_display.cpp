// SDL2 window used by tb_201_video as a live NES display (DPI-C).
#include <SDL.h>

#include <cstdint>
#include <cstdio>
#include <initializer_list>

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
int pending = 0;

// X = A, Z = B, Right Shift/Backspace = Select, Enter = Start, arrows = D-pad
int pad_bit(int sc) {
    switch (sc) {
        case SDL_SCANCODE_RIGHT: return 0x01;
        case SDL_SCANCODE_DOWN: return 0x02;
        case SDL_SCANCODE_RSHIFT: return 0x04;
        case SDL_SCANCODE_RETURN: return 0x08;
        case SDL_SCANCODE_W: return 0x10;
        case SDL_SCANCODE_S: return 0x20;
        case SDL_SCANCODE_A: return 0x40;
        case SDL_SCANCODE_D: return 0x80;
    }
    return 0;
}
int pad_state = 0;  // bit order: A, B, Select, Start, Up, Down, Left, Right
uint32_t fps_ticks = 0;

constexpr int AUDIO_RATE = 44100;
constexpr int CPU_HZ = 1789773;
constexpr uint32_t AUDIO_BATCH = 512;                       // samples queued per SDL call
constexpr uint32_t AUDIO_MAX_QUEUED = AUDIO_RATE / 10 * sizeof(float);  // ~100 ms

SDL_AudioDeviceID audio_dev = 0;
int audio_acc = 0;
float audio_buf[AUDIO_BATCH];
uint32_t audio_fill = 0;
float mix_table[31];  // index = pulse1 + pulse2 (each 0..15), NES nonlinear pulse mixer

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
    SDL_RaiseWindow(window);
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
        if (e.type == SDL_KEYDOWN && !e.key.repeat) pending |= pad_bit(e.key.keysym.scancode);
    }

    // Held keys plus any key tapped since the last frame, so short taps are not missed.
    const uint8_t* keys = SDL_GetKeyboardState(nullptr);
    int held = 0;
    for (int sc : {SDL_SCANCODE_RIGHT, SDL_SCANCODE_DOWN, SDL_SCANCODE_RSHIFT,
                   SDL_SCANCODE_RETURN, SDL_SCANCODE_W, SDL_SCANCODE_S, SDL_SCANCODE_A,
                   SDL_SCANCODE_D})
        if (keys[sc]) held |= pad_bit(sc);
    pad_state = held | pending;
    pending = 0;

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

int sdl_display_buttons(void) { return pad_state; }

void sdl_audio_init(void) {
    if (audio_dev) return;
    if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
        std::fprintf(stderr, "sdl_display: audio init failed: %s\n", SDL_GetError());
        return;
    }
    SDL_AudioSpec want{};
    want.freq = AUDIO_RATE;
    want.format = AUDIO_F32SYS;
    want.channels = 1;
    want.samples = 1024;
    audio_dev = SDL_OpenAudioDevice(nullptr, 0, &want, nullptr, 0);
    if (!audio_dev) {
        std::fprintf(stderr, "sdl_display: audio device failed: %s\n", SDL_GetError());
        return;
    }
    mix_table[0] = 0.0f;
    for (int n = 1; n < 31; n++) mix_table[n] = 95.88f / (8128.0f / n + 100.0f);
    SDL_PauseAudioDevice(audio_dev, 0);
}

// Call once per CPU clock with the two 4-bit pulse volumes; resamples to AUDIO_RATE.
void sdl_audio_sample(int audio1, int audio2) {
    if (!audio_dev) return;
    audio_acc += AUDIO_RATE;
    if (audio_acc < CPU_HZ) return;
    audio_acc -= CPU_HZ;
    audio_buf[audio_fill++] = mix_table[(audio1 & 0xF) + (audio2 & 0xF)];
    if (audio_fill < AUDIO_BATCH) return;
    audio_fill = 0;

    // Throttle the simulation to real time so the queue neither starves nor grows.
    while (SDL_GetQueuedAudioSize(audio_dev) > AUDIO_MAX_QUEUED) SDL_Delay(1);
    SDL_QueueAudio(audio_dev, audio_buf, sizeof(audio_buf));
}

void sdl_audio_close(void) {
    if (!audio_dev) return;
    SDL_CloseAudioDevice(audio_dev);
    audio_dev = 0;
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
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
