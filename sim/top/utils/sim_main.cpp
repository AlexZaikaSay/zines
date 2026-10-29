// Generated per live testbench by CMake. Drives clk from C++ so Verilator runs
// without --timing (no coroutine scheduler); the testbench ends itself with $finish.
#include "V@TB_NAME@.h"
#include "verilated.h"

#include <cstdint>
#include <memory>

// NTSC PPU clock 5.369318 MHz -> half period 93.12 ns. timeInc() counts in the
// design's time precision (1ps from `timescale 1ns/1ps), so waveforms show real time.
static constexpr uint64_t HALF_PERIOD_PS = 93120;

int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> ctx{new VerilatedContext};
    ctx->commandArgs(argc, argv);
    const std::unique_ptr<V@TB_NAME@> top{new V@TB_NAME@{ctx.get()}};

    ctx->traceEverOn(true);
    top->clk = 0;
    top->eval();
    while (!ctx->gotFinish()) {
        ctx->timeInc(HALF_PERIOD_PS);
        top->clk = 1;
        top->eval();
        ctx->timeInc(HALF_PERIOD_PS);
        top->clk = 0;
        top->eval();
    }
    top->final();
    return 0;
}
