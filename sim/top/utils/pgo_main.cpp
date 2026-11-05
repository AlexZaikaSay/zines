// Training run for profile-guided optimisation of the zines model (no window).
// Runs the menu, the game load and 300 NES frames of play with fixed clock
// counts; pgo_stub.cpp stands in for SDL and presses Start in the menu. The
// profile it writes (LLVM_PROFILE_FILE) is used to build the real zines binary.
#include "Vzines.h"
#include "verilated.h"

#include <cstdio>

int main(int argc, char** argv) {
    VerilatedContext ctx;
    ctx.commandArgs(argc, argv);
    Vzines top{&ctx};

    // menu + SD load takes ~31M clocks, then 300 NES frames of 89342 dots
    const long clocks = 33000000L + 89342L * 300;
    for (long i = 0; i < clocks && !ctx.gotFinish(); ++i) {
        ctx.timeInc(1);
        top.clk = 1;
        top.eval();
        ctx.timeInc(1);
        top.clk = 0;
        top.eval();
    }
    top.final();
    std::printf("pgo training: %ld clocks\n", clocks);
    return 0;
}
