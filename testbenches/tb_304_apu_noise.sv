`include "boards/rp_devboard.sv"

/* verilator lint_off STMTDLY */

// Checks the noise output of tests/asm/304_apu_noise.ca65 against the 2A03 spec:
//   timing  = the LFSR steps every period CPU cycles (period table: 4, 8, 16 .. 4068),
//             so the output only changes on a step boundary
//   mode 0  = 15-bit LFSR, feedback bit0 ^ bit1: 32767-step sequence, no short repeat
//   mode 1  = feedback bit0 ^ bit6: 93-step sequence ("metallic")
//   output  = volume when LFSR bit 0 is 0, silent otherwise
//   volume  = constant volume or decaying envelope
//   length  = length table entry * half-frame (~14915 CPU cycles)
//   pulse 1/2 and triangle stay silent
module tb_304_apu_noise;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/304_apu_noise.tv";

    localparam HALF_FRAME   = 14915;    // CPU cycles between length counter clocks
    localparam RUN_CYCLES   = 2500000;
    localparam NOTES        = 3;
    localparam MAX_BITS     = 8192;
    localparam SHORT_LEN    = 93;       // sequence length in short mode
    // A new period is used from the next timer reload, so the first step of a note can
    // still take the previous period (at most 4068 cycles): sync after that.
    localparam SETTLE       = 4200;

    // Expected notes: $400E value, LFSR period in CPU cycles, $400C value, length table value
    integer exp_mode   [NOTES];
    integer exp_period [NOTES];
    integer exp_ctrl   [NOTES];
    integer exp_len    [NOTES];

    logic clk;
    logic rst_n;
    logic running;      // checks are enabled once reset is released
    logic [3:0] audio1;
    logic [3:0] audio2;
    logic [3:0] audio3;
    logic [3:0] audio3_idle;  // triangle level after reset
    logic [3:0] audio4;

    rp_devboard #(
        .MEM_FILE(MEM_FILE)
    ) db_device (
        .clk(clk),
        .rst_n(rst_n),
        .audio1(audio1),
        .audio2(audio2),
        .audio3(audio3),
        .audio4(audio4)
    );

    wire        w_length = db_device.cpu.u_apu.w_noise_timer;
    wire [4:0]  len_index = db_device.cpu.u_apu.data_in[7:3];   // $400F length index
    wire        noise_active = db_device.cpu.u_apu.noise_active;    // $4015 bit 3

    integer cyc;
    integer note;           // index of the running note, -1 before the first one
    integer note_start;
    integer len_end;        // cycle the length counter reached zero
    integer sync_at;        // first output change of the note: an LFSR step
    integer timing_errs;
    integer vol_errs;
    integer env_max;
    integer env_last;
    integer env_drops;
    integer nbits;          // LFSR output bits sampled, one per step
    logic   bits [MAX_BITS];
    logic [3:0] prev;

    function automatic integer abs_i(input integer v);
        return v < 0 ? -v : v;
    endfunction

    function automatic integer len_of(input logic [4:0] idx);
        case (idx)
            0: return 10;  1: return 254; 2: return 20;  3: return 2;
            4: return 40;  5: return 4;   6: return 80;  7: return 6;
            8: return 160; 9: return 8;   10: return 60; 11: return 10;
            12: return 14; 13: return 12; 14: return 26; 15: return 14;
            16: return 12; 17: return 16; 18: return 24; 19: return 18;
            20: return 48; 21: return 20; 22: return 96; 23: return 22;
            24: return 192; 25: return 24; 26: return 72; 27: return 26;
            28: return 16; 29: return 28; 30: return 32; default: return 30;
        endcase
    endfunction

    // 1 when the sampled bit stream repeats with period p
    function automatic logic repeats_with(input integer p);
        for (integer i = 0; i + p < nbits; i++)
            if (bits[i] != bits[i + p])
                return 1'b0;
        return 1'b1;
    endfunction

    task automatic finish_note(input integer idx);
        integer expect_len, dur, ones;
        logic short_mode;
        begin
            if (idx >= 0) begin
                short_mode = exp_mode[idx][7];
                expect_len = exp_len[idx] * HALF_FRAME;
                dur = len_end - note_start;
                ones = 0;
                for (integer i = 0; i < nbits; i++)
                    ones += 32'(bits[i]);

                if (nbits < 500)
                    $error("TEST FAILED: note %0d: only %0d LFSR steps sampled", idx, nbits);
                if (timing_errs != 0)
                    $error("TEST FAILED: note %0d: %0d output changes off the %0d-cycle step grid",
                           idx, timing_errs, exp_period[idx]);
                if (short_mode) begin
                    if (!repeats_with(SHORT_LEN))
                        $error("TEST FAILED: note %0d: short mode does not repeat every %0d steps",
                               idx, SHORT_LEN);
                    if (repeats_with(31) || repeats_with(3))
                        $error("TEST FAILED: note %0d: short mode repeats faster than %0d steps",
                               idx, SHORT_LEN);
                end else begin
                    for (integer p = 1; p <= 200; p++)
                        if (repeats_with(p))
                            $error("TEST FAILED: note %0d: long mode repeats every %0d steps", idx, p);
                    if (ones * 10 < nbits * 4 || ones * 10 > nbits * 6)
                        $error("TEST FAILED: note %0d: %0d of %0d steps audible, expected ~50%%",
                               idx, ones, nbits);
                end
                if (vol_errs != 0)
                    $error("TEST FAILED: note %0d: %0d samples with wrong volume", idx, vol_errs);
                if (exp_ctrl[idx][4] == 1'b0) begin
                    if (env_max != 15)
                        $error("TEST FAILED: note %0d: envelope starts at %0d, expected 15", idx, env_max);
                    if (env_drops == 0)
                        $error("TEST FAILED: note %0d: envelope does not decay", idx);
                end
                if (len_end < 0 || abs_i(dur - expect_len) > HALF_FRAME)
                    $error("TEST FAILED: note %0d: length %0d cycles, expected ~%0d (%0d half-frames)",
                           idx, dur, expect_len, exp_len[idx]);

                $display("note %0d: %s mode, period %0d, %0d steps (%0d audible), %s, length %0d cycles",
                         idx, short_mode ? "short" : "long", exp_period[idx], nbits, ones,
                         exp_ctrl[idx][4] ? "constant volume 15" : "envelope", dur);
            end
        end
    endtask

    initial begin
        exp_mode[0] = 'h04; exp_period[0] = 64;  exp_ctrl[0] = 'h1F; exp_len[0] = 20;
        exp_mode[1] = 'h84; exp_period[1] = 64;  exp_ctrl[1] = 'h1F; exp_len[1] = 20;
        exp_mode[2] = 'h08; exp_period[2] = 202; exp_ctrl[2] = 'h03; exp_len[2] = 40;
        cyc = 0;
        note = -1;
        note_start = 0;
        len_end = -1;
        sync_at = -1;
        timing_errs = 0;
        vol_errs = 0;
        env_max = 0;
        env_last = 16;
        env_drops = 0;
        nbits = 0;
        prev = 0;
    end

    initial begin
        $dumpfile("tb_304_apu_noise.vcd");
        $dumpvars(0, tb_304_apu_noise);
        rst_n = 0;
        running = 0;
        clk = 0;
        // Clock the design while reset is held: rst_n starts low, so there is no
        // negedge, and the flops only see reset on a clock edge. The LFSR has to
        // reset to 1 (from 0 it never leaves 0).
        #1 rst_n = 0;
        repeat (2) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
        end
        rst_n = 1; running = 1; audio3_idle = audio3;
        for (integer i = 0; i < RUN_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
        end
        $error("TEST FAILED: timeout, only %0d notes started", note + 1);
        $finish;
    end

    always @(posedge clk) begin
        // Only the noise channel is enabled by this program
        if (audio1 != 0)
            $error("FAIL: pulse 1 output %0d, expected silence", audio1);
        if (audio2 != 0)
            $error("FAIL: pulse 2 output %0d, expected silence", audio2);
        // A stopped triangle holds its level (15 after reset) instead of going to 0
        if (running && audio3 != audio3_idle)
            $error("FAIL: triangle output changed %0d -> %0d, expected it to stay idle",
                   audio3_idle, audio3);

        if (running) begin
            cyc <= cyc + 1;
            prev <= audio4;

            if (note >= 0 && len_end < 0 && cyc - note_start > 2 && !noise_active)
                len_end <= cyc;

            if (w_length) begin
                // The ca65 program writes $400C, $400E, then $400F (starts the note).
                // A final $400F write after the last note ends the test.
                finish_note(note);
                note <= note + 1;
                if (note + 1 == NOTES) begin
                    $display("tb_304_apu_noise done");
                    $finish;
                end else begin
                    if (len_of(len_index) !== exp_len[note + 1])
                        $error("TEST FAILED: note %0d: length %0d, expected %0d",
                               note + 1, len_of(len_index), exp_len[note + 1]);
                end
                note_start <= cyc;
                len_end <= -1;
                sync_at <= -1;
                timing_errs <= 0;
                vol_errs <= 0;
                env_max <= 0;
                env_last <= 16;
                env_drops <= 0;
                nbits <= 0;
            end else if (note >= 0 && note < NOTES && noise_active) begin
                // An LFSR step switches between silent and audible (the envelope only
                // changes the level). The first one after SETTLE fixes the grid.
                if ((audio4 == 0) != (prev == 0) && cyc - note_start > SETTLE) begin
                    if (sync_at < 0)
                        sync_at <= cyc;
                    else if ((cyc - sync_at) % exp_period[note] != 0)
                        timing_errs <= timing_errs + 1;
                end

                // One output bit per step, sampled in the middle of the step
                if (sync_at >= 0 && (cyc - sync_at) % exp_period[note] == exp_period[note] / 2 &&
                    nbits < MAX_BITS) begin
                    bits[nbits] <= (audio4 != 0);
                    nbits <= nbits + 1;
                end

                if (audio4 != 0) begin
                    if (exp_ctrl[note][4] == 1'b1 && 32'(audio4) != (exp_ctrl[note] & 'hF))
                        vol_errs <= vol_errs + 1;
                    if (exp_ctrl[note][4] == 1'b0) begin
                        if (32'(audio4) > env_max) env_max <= 32'(audio4);
                        if (env_last != 16 && 32'(audio4) > env_last)
                            vol_errs <= vol_errs + 1;
                        if (env_last != 16 && 32'(audio4) < env_last)
                            env_drops <= env_drops + 1;
                        env_last <= 32'(audio4);
                    end
                end
            end
        end
    end
endmodule

/* verilator lint_on STMTDLY */
