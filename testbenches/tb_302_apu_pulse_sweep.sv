
`include "boards/rp_devboard.sv"

/* verilator lint_off STMTDLY */

// Test 302: NES APU Pulse 1 hardware sweep.
//
// Expected sequence:
//   0: Positive A4, period $0FD
//   1: Negative A4, period $0FD
//   2: Positive D6, period $05D
//   3: Negative D6, period $05D
//
// Checks:
//   - Actual audio1 output transitions
//   - Pulse periods and duty cycle before sweep changes the timer
//   - Constant volume
//   - Length-counter duration
//   - Sweep direction and live timer updates

module tb_302_apu_pulse_sweep;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/302_apu_pulse_sweep.tv";

    localparam HALF_FRAME = 14915;
    localparam SETTLE = 16000;
    localparam RUN_CYCLES = 2000000;
    localparam NOTES = 4;

    integer exp_period [0:NOTES-1];
    integer exp_sweep  [0:NOTES-1];
    integer exp_len    [0:NOTES-1];
    integer exp_dir    [0:NOTES-1];

    logic clk;
    logic rst_n;
    logic running;      // checks are enabled once reset is released
    logic [3:0] audio2;
    logic [3:0] audio3;
    logic [3:0] audio3_idle;  // triangle level after reset
    logic [3:0] audio4;
    logic [3:0] audio1;

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

    wire        w_timer1 = db_device.cpu.u_apu.w_pulse1_timer1;
    wire        w_timer2 = db_device.cpu.u_apu.w_pulse1_timer2;
    // 32-bit views of APU state so they compare cleanly with integers
    wire [31:0] timer_now = {21'd0, db_device.cpu.u_apu.u_pulse1.timer};
    wire [31:0] sweep_now = {24'd0, db_device.cpu.u_apu.u_pulse1.sweep};
    // timer period being written by $4003: data[2:0] high bits + $4002 low byte
    wire [31:0] new_period = {21'd0, db_device.cpu.u_apu.data_in[2:0],
                              db_device.cpu.u_apu.u_pulse1.timer[7:0]};
    wire [7:0]  apu_ctrl = db_device.cpu.u_apu.u_pulse1.settings;

    integer cyc;
    integer note;
    integer note_start;
    integer len_end;

    integer edges;
    integer period_errs;
    integer duty_errs;
    integer vol_errs;
    integer sweep_updates;
    integer audible_samples;

    integer last_period;
    integer timer_at_rise;
    integer rise_at;
    integer high_start;
    logic   timer_changed_since_rise;
    integer last_update_at;
    integer mute_errs;
    integer value_errs;
    integer rate_errs;
    logic   timer_write_d;

    logic [3:0] prev;

    function automatic integer abs_i(input integer v);
        return v < 0 ? -v : v;
    endfunction

    // Expected next timer for Pulse 1 (ones' complement negate).
    function automatic integer sweep_next(input integer t, input integer sw);
        integer change;
        change = t >> (sw & 7);
        return ((sw & 8) != 0) ? t - change - 1 : t + change;
    endfunction

    // Pulse 1 is silent when timer < 8 or the positive target overflows.
    function automatic logic muted(input integer t, input integer sw);
        return t < 8 || ((sw & 8) == 0 && sweep_next(t, sw) > 'h7FF);
    endfunction

    function automatic integer len_of(input logic [4:0] idx);
        case (idx)
             0: return 10;   1: return 254;
             2: return 20;   3: return 2;
             4: return 40;   5: return 4;
             6: return 80;   7: return 6;
             8: return 160;  9: return 8;
            10: return 60;  11: return 10;
            12: return 14;  13: return 12;
            14: return 26;  15: return 14;
            16: return 12;  17: return 16;
            18: return 24;  19: return 18;
            20: return 48;  21: return 20;
            22: return 96;  23: return 22;
            24: return 192; 25: return 24;
            26: return 72;  27: return 26;
            28: return 16;  29: return 28;
            30: return 32;  default: return 30;
        endcase
    endfunction

    task automatic finish_note(input integer idx);
        integer dur;
        integer expected_dur;
        begin
            if (idx >= 0 && idx < NOTES) begin
                dur = len_end - note_start;
                expected_dur = exp_len[idx] * HALF_FRAME;

                if (edges < 3)
                    $error("FAIL note %0d: only %0d audio edges detected",
                           idx + 1, edges);

                if (period_errs != 0)
                    $error("FAIL note %0d: %0d pulse-period errors",
                           idx + 1, period_errs);

                if (duty_errs > 1)
                    $error("FAIL note %0d: %0d duty-cycle errors",
                           idx + 1, duty_errs);

                if (vol_errs != 0)
                    $error("FAIL note %0d: %0d volume errors",
                           idx + 1, vol_errs);

                if (value_errs != 0)
                    $error("FAIL note %0d: %0d wrong sweep target values",
                           idx + 1, value_errs);

                if (rate_errs != 0)
                    $error("FAIL note %0d: %0d sweep updates at wrong rate",
                           idx + 1, rate_errs);

                if (mute_errs != 0)
                    $error("FAIL note %0d: %0d samples audible while muted",
                           idx + 1, mute_errs);

                if (sweep_updates == 0)
                    $error("FAIL note %0d: sweep never changed timer",
                           idx + 1);

                if (len_end < 0 ||
                    abs_i(dur - expected_dur) > HALF_FRAME)
                    $error("FAIL note %0d: length=%0d, expected about %0d cycles",
                           idx + 1, dur, expected_dur);

                $display(
                    "note %0d: start=$%03h, sweep=$%02h, edges=%0d, timer updates=%0d, length=%0d cycles",
                    idx + 1, exp_period[idx], exp_sweep[idx],
                    edges, sweep_updates, dur
                );
            end
        end
    endtask

    initial begin
        exp_period[0] = 'h0FD;
        exp_period[1] = 'h0FD;
        exp_period[2] = 'h05D;
        exp_period[3] = 'h05D;

        exp_sweep[0] = 'h91;
        exp_sweep[1] = 'h99;
        exp_sweep[2] = 'h91;
        exp_sweep[3] = 'h99;

        exp_dir[0] =  1;
        exp_dir[1] = -1;
        exp_dir[2] =  1;
        exp_dir[3] = -1;

        exp_len[0] = 20;
        exp_len[1] = 20;
        exp_len[2] = 20;
        exp_len[3] = 20;

        cyc = 0;
        note = -1;
        note_start = 0;
        len_end = -1;
        edges = 0;
        period_errs = 0;
        duty_errs = 0;
        vol_errs = 0;
        sweep_updates = 0;
        audible_samples = 0;
        last_period = -1;
        timer_at_rise = -1;
        rise_at = -1;
        high_start = -1;
        timer_changed_since_rise = 0;
        last_update_at = -1;
        mute_errs = 0;
        value_errs = 0;
        rate_errs = 0;
        timer_write_d = 0;
        prev = 0;
    end

    initial begin
        $dumpfile("tb_302_apu_pulse_sweep.vcd");
        $dumpvars(0, tb_302_apu_pulse_sweep);

        rst_n = 0;
        running = 0;
        clk = 0;
        #1;
        // Clock the design while reset is held: rst_n starts low, so there is no
        // negedge, and the flops only see reset on a clock edge.
        repeat (2) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
        end
        rst_n = 1;
        running = 1;
        audio3_idle = audio3;

        for (integer i = 0; i < RUN_CYCLES; i++) begin
            clk = 1;
            #(CYCLE_LEN / 2);
            clk = 0;
            #(CYCLE_LEN / 2);
        end

        $error("TEST FAILED: timeout; only %0d of %0d notes started",
               note + 1, NOTES);
        $finish;
    end

    always @(posedge clk) begin
        // Only pulse 1 is enabled by this program
        if (audio2 != 0)
            $error("FAIL: pulse 2 output %0d, expected silence", audio2);
        // A stopped triangle holds its level (15 after reset) instead of going to 0
        if (running && audio3 != audio3_idle)
            $error("FAIL: triangle output changed %0d -> %0d, expected it to stay idle",
                   audio3_idle, audio3);
        if (audio4 != 0)
            $error("FAIL: noise output %0d, expected silence", audio4);

        if (running) begin
            cyc <= cyc + 1;
            // Timer register changes one cycle after a $4002/$4003 write.
            timer_write_d <= w_timer1 | w_timer2;

            if (note >= 0 && len_end < 0 &&
                cyc - note_start > 2 &&
                db_device.cpu.u_apu.u_pulse1.len_counter == 0)
                len_end <= cyc;

            // Same note-start marker used by test 301.
            if (w_timer2) begin
                finish_note(note);

                if (note + 1 >= NOTES) begin
                    $display("TEST 302 PASSED: all four sweep notes completed");
                    $finish;
                end

                note <= note + 1;
                note_start <= cyc;
                len_end <= -1;

                edges <= 0;
                period_errs <= 0;
                duty_errs <= 0;
                vol_errs <= 0;
                sweep_updates <= 0;
                audible_samples <= 0;

                last_period <= timer_now;
                timer_at_rise <= -1;
                rise_at <= -1;
                high_start <= -1;
                timer_changed_since_rise <= 0;
                last_update_at <= -1;
                mute_errs <= 0;
                value_errs <= 0;
                rate_errs <= 0;

                if (note + 1 < NOTES) begin
                    if (new_period !==
                        exp_period[note + 1])
                        $error("FAIL note %0d: initial timer=%03h expected=%03h",
                               note + 2,
                               new_period,
                               exp_period[note + 1]);

                    if (sweep_now !==
                        exp_sweep[note + 1])
                        $error("FAIL note %0d: sweep=%02h expected=%02h",
                               note + 2,
                               sweep_now,
                               exp_sweep[note + 1]);

                    if (apu_ctrl !== 8'h9F)
                        $error("FAIL note %0d: pulse control=%02h expected=9F",
                               note + 2, apu_ctrl);

                    $display("START note %0d: %s sweep, timer=$%03h",
                             note + 2,
                             exp_dir[note + 1] > 0 ? "positive" : "negative",
                             exp_period[note + 1]);
                end
            end else if (w_timer1 || timer_write_d) begin
                last_period <= timer_now;
            end else if (note >= 0 && note < NOTES) begin
                begin
                    if (timer_now != last_period) begin
                        if (timer_now !=
                            sweep_next(last_period, exp_sweep[note])) begin
                            value_errs <= value_errs + 1;
                            $error("FAIL note %0d: sweep %03h -> %03h, expected %03h",
                                note + 1, last_period,
                                timer_now,
                                sweep_next(last_period, exp_sweep[note]));
                        end

                        // Divider period P = 1 -> update every P+1 = 2 half-frames.
                        if (last_update_at >= 0 &&
                            abs_i(cyc - last_update_at - 2 * HALF_FRAME) > 4) begin
                            rate_errs <= rate_errs + 1;
                            $error("FAIL note %0d: sweep update after %0d cycles, expected %0d",
                                note + 1, cyc - last_update_at, 2 * HALF_FRAME);
                        end
                        last_update_at <= cyc;

                        if ((exp_dir[note] > 0 &&
                            timer_now <= last_period) ||
                            (exp_dir[note] < 0 &&
                            timer_now >= last_period))
                            $error("FAIL note %0d: wrong sweep direction, %03h -> %03h",
                                note + 1, last_period,
                                timer_now);

                        sweep_updates <= sweep_updates + 1;
                        last_period <= timer_now;
                        timer_changed_since_rise <= 1;

                        $display("note %0d: timer %03h -> %03h",
                                note + 1, last_period,
                                timer_now);
                    end
                end

                if (muted(timer_now, exp_sweep[note]) &&
                    audio1 != 0)
                    mute_errs <= mute_errs + 1;

                // Track prev all the time, so the first sample after SETTLE
                // is not mistaken for a rising edge in the middle of a pulse.
                if (audio1 != prev)
                    prev <= audio1;

                if (cyc - note_start > SETTLE) begin

                    if (audio1 != 0 && audio1 != 4'bxxxx) begin
                        audible_samples <= audible_samples + 1;

                        if (audio1 != 4'd15)
                            vol_errs <= vol_errs + 1;
                    end

                    // Measure actual audio rising edges. Compare with the
                    // timer only when no sweep update occurred in the interval.
                    if (prev == 0 && audio1 != 0) begin
                        if (rise_at >= 0 && !timer_changed_since_rise) begin
                            if (abs_i((cyc - rise_at) -
                                16 * (timer_at_rise + 1)) > 2)
                                period_errs <= period_errs + 1;

                            edges <= edges + 1;
                        end else if (rise_at < 0) begin
                            edges <= edges + 1;
                        end

                        rise_at <= cyc;
                        timer_at_rise <= timer_now;
                        timer_changed_since_rise <= 0;
                    end

                    // Measure the high part of each pulse for 50% duty.
                    if (prev != 0 && audio1 == 0) begin
                        if (high_start >= 0 && !timer_changed_since_rise &&
                            abs_i((cyc - high_start) -
                                8 * (timer_at_rise + 1)) > 2)
                            duty_errs <= duty_errs + 1;
                    end

                    if (prev == 0 && audio1 != 0)
                        high_start <= cyc;

                    if (prev != 0 && audio1 == 0)
                        high_start <= -1;
                end
            end
        end
    end
endmodule

/* verilator lint_on STMTDLY */
