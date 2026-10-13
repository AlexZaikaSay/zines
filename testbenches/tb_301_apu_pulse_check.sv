`include "boards/rp_devboard.sv"

/* verilator lint_off STMTDLY */

// Checks pulse 1 output of tests/asm/301_apu_pulse_check.ca65 against the 2A03 spec:
//   frequency = CPU_HZ / (16 * (period + 1))
//   length    = length table entry * half-frame (~14915 CPU cycles)
//   volume    = constant volume or decaying envelope
module tb_301_apu_pulse_check;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/301_apu_pulse_check.tv";

    localparam HALF_FRAME   = 14915;    // CPU cycles between length counter clocks
    localparam SETTLE       = 16000;    // first quarter frame has to load the envelope
    localparam RUN_CYCLES   = 2000000;
    localparam NOTES        = 3;

    // Expected notes: timer period, length table value, volume (15 = constant 15, 0 = envelope)
    integer exp_period [NOTES];
    integer exp_len    [NOTES];
    integer exp_const  [NOTES];

    logic clk;
    logic rst_n;
    logic [3:0] audio1;
    logic [3:0] audio2;

    rp_devboard #(
        .MEM_FILE(MEM_FILE)
    ) db_device (
        .clk(clk),
        .rst_n(rst_n),
        .audio1(audio1),
        .audio2(audio2)
    );

    wire        w_timer2 = db_device.cpu.u_apu.w_pulse1_timer2;
    wire [7:0]  apu_data = db_device.cpu.u_apu.data_in;
    wire [10:0] apu_timer = db_device.cpu.u_apu.pulse1_timer;
    wire [7:0]  apu_ctrl = db_device.cpu.u_apu.pulse1_settings;

    integer cyc;
    integer note;           // index of the running note, -1 before the first one
    integer note_start;
    integer last_nz;        // last cycle with audible output
    integer rise_at;
    integer fall_at;
    integer edges;
    integer period_errs;
    integer duty_errs;
    integer vol_errs;
    integer env_max;
    integer env_last;
    integer env_drops;
    integer len_end;
    integer period_reg;
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

    task automatic finish_note(input integer idx, input integer end_cyc);
        integer expect_len, dur;
        begin
            if (idx >= 0) begin
                if (edges < 3)
                    $error("TEST FAILED: note %0d: only %0d periods detected", idx, edges);
                if (period_errs != 0)
                    $error("TEST FAILED: note %0d: %0d periods differ from %0d CPU cycles (%f Hz)",
                           idx, period_errs, 16 * (exp_period[idx] + 1),
                           1789773.0 / (16 * (exp_period[idx] + 1)));
                // the last pulse is cut short by the length counter
                if (duty_errs > 1)
                    $error("TEST FAILED: note %0d: %0d pulses are not 50%% duty", idx, duty_errs);
                if (vol_errs != 0)
                    $error("TEST FAILED: note %0d: %0d samples with wrong volume", idx, vol_errs);
                // Length counter runs out after len * half-frame cycles (+-1 half-frame).
                expect_len = exp_len[idx] * HALF_FRAME;
                dur = len_end - note_start;
                if (len_end < 0 || dur > expect_len + HALF_FRAME || dur < expect_len - HALF_FRAME)
                    $error("TEST FAILED: note %0d: length %0d cycles, expected ~%0d (%0d half-frames)",
                           idx, dur, expect_len, exp_len[idx]);
                if (idx < 2) begin
                    if (last_nz > len_end + 16 * (exp_period[idx] + 1))
                        $error("TEST FAILED: note %0d: sound continues after length counter ended", idx);
                    $display("note %0d: %0d Hz, length %0d cycles (%0d half-frames), volume 15 OK",
                             idx, 1789773 / (16 * (exp_period[idx] + 1)), dur, exp_len[idx]);
                end else begin
                    if (env_max != 15)
                        $error("TEST FAILED: note %0d: envelope starts at %0d, expected 15", idx, env_max);
                    if (env_drops == 0)
                        $error("TEST FAILED: note %0d: envelope does not decay", idx);
                    $display("note %0d: %0d Hz, length %0d cycles, envelope decays from %0d (%0d steps) OK",
                             idx, 1789773 / (16 * (exp_period[idx] + 1)), dur, env_max, env_drops);
                end
            end
        end
    endtask

    initial begin
        // A4 / D6 periods and lengths (LEN_8TH -> index 2, LEN_WHOLE -> index 4)
        exp_period[0] = 16'h00FD; exp_len[0] = 20; exp_const[0] = 15;
        exp_period[1] = 16'h005D; exp_len[1] = 20; exp_const[1] = 15;
        exp_period[2] = 16'h00FD; exp_len[2] = 40; exp_const[2] = 0;
        cyc = 0;
        note = -1;
        note_start = 0;
        last_nz = 0;
        len_end = -1;
        prev = 0;
        rise_at = -1;
        fall_at = -1;
        edges = 0;
        period_errs = 0;
        duty_errs = 0;
        vol_errs = 0;
        env_max = 0;
        env_last = 16;
        env_drops = 0;
    end

    initial begin
        $dumpfile("tb_301_apu_pulse_check.vcd");
        $dumpvars(0, tb_301_apu_pulse_check);
        rst_n = 0;
        clk = 0;
        #1 rst_n = 0; #(CYCLE_LEN * 2); rst_n = 1;
        for (integer i = 0; i < RUN_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
        end
        $error("TEST FAILED: timeout, only %0d notes started", note + 1);
        $finish;
    end

    always @(posedge clk) begin
        if (rst_n === 1'b1) begin
            cyc <= cyc + 1;
            if (note >= 0 && len_end < 0 && cyc - note_start > 2 && db_device.cpu.u_apu.pulse1_len_counter == 0)
                len_end <= cyc;

            if (w_timer2) begin
                // The ca65 program writes $4000, $4002, then $4003 (starts the note).
                finish_note(note, cyc);
                note <= note + 1;
                if (note + 1 == NOTES) begin
                    $display("tb_301_apu_pulse_check done");
                    $finish;
                end
                if (note + 1 < NOTES) begin
                    period_reg = {apu_data[2:0], apu_timer[7:0]};
                    if (period_reg !== exp_period[note + 1] || len_of(apu_data[7:3]) !== exp_len[note + 1])
                        $error("TEST FAILED: note %0d: period $%03h length %0d, expected $%03h and %0d",
                               note + 1, period_reg, len_of(apu_data[7:3]), exp_period[note + 1], exp_len[note + 1]);
                    if (exp_const[note + 1] != 0 && apu_ctrl !== 8'h9F)
                        $error("TEST FAILED: note %0d: $4000=%h, expected 9F", note + 1, apu_ctrl);
                end
                note_start <= cyc;
                last_nz <= cyc;
                len_end <= -1;
                prev <= 0;
                rise_at <= -1;
                fall_at <= -1;
                edges <= 0;
                period_errs <= 0;
                duty_errs <= 0;
                vol_errs <= 0;
                env_max <= 0;
                env_last <= 16;
                env_drops <= 0;
            end else if (note >= 0 && note < NOTES) begin
                if (audio1 !== 4'bxxxx && audio1 != 0)
                    last_nz <= cyc;
                if (cyc - note_start > SETTLE) begin
                    prev <= audio1;
                    if (exp_const[note] != 0 && audio1 != 0 && audio1 != 4'd15)
                        vol_errs <= vol_errs + 1;
                    if (exp_const[note] == 0 && audio1 != 0) begin
                        if (audio1 > env_max) env_max <= audio1;
                        if (env_last != 16 && audio1 > env_last)
                            vol_errs <= vol_errs + 1;
                        if (env_last != 16 && audio1 < env_last)
                            env_drops <= env_drops + 1;
                        env_last <= audio1;
                    end
                    if (prev == 0 && audio1 != 0) begin
                        if (rise_at >= 0) begin
                            edges <= edges + 1;
                            // the first interval can still carry the previous note's timer
                            if (edges > 0 && abs_i((cyc - rise_at) - 16 * (exp_period[note] + 1)) > 2)
                                period_errs <= period_errs + 1;
                        end
                        rise_at <= cyc;
                    end
                    if (prev != 0 && audio1 == 0) begin
                        if (edges > 0 && rise_at >= 0 && abs_i((cyc - rise_at) - 8 * (exp_period[note] + 1)) > 2)
                            duty_errs <= duty_errs + 1;
                    end
                end
            end
        end
    end
endmodule

/* verilator lint_on STMTDLY */
