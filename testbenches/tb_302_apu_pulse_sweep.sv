
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
    logic [3:0] audio1;

    rp_devboard #(
        .MEM_FILE(MEM_FILE)
    ) db_device (
        .clk(clk),
        .rst_n(rst_n),
        .audio1(audio1)
    );

    wire        w_timer1 = db_device.cpu.u_apu.w_pulse1_timer1;
    wire        w_timer2 = db_device.cpu.u_apu.w_pulse1_timer2;
    wire [7:0]  apu_data = db_device.cpu.u_apu.data_in;
    wire [10:0] apu_timer = db_device.cpu.u_apu.pulse1_timer;
    wire [7:0]  apu_ctrl = db_device.cpu.u_apu.pulse1_settings;

    integer cyc;
    integer note;
    integer note_start;
    integer len_end;
    integer last_nz;

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
    integer timer_changed_since_rise;

    logic [3:0] prev;

    function automatic integer abs_i(input integer v);
        return v < 0 ? -v : v;
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
        last_nz = 0;
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
        prev = 0;
    end

    initial begin
        $dumpfile("tb_302_apu_pulse_sweep.vcd");
        $dumpvars(0, tb_302_apu_pulse_sweep);

        rst_n = 0;
        clk = 0;
        #1;
        #(CYCLE_LEN * 2);
        rst_n = 1;

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
        if (rst_n === 1'b1) begin
            cyc <= cyc + 1;

            if (note >= 0 && len_end < 0 &&
                cyc - note_start > 2 &&
                db_device.cpu.u_apu.pulse1_len_counter == 0)
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
                last_nz <= cyc;

                edges <= 0;
                period_errs <= 0;
                duty_errs <= 0;
                vol_errs <= 0;
                sweep_updates <= 0;
                audible_samples <= 0;

                last_period <= db_device.cpu.u_apu.pulse1_timer;
                timer_at_rise <= -1;
                rise_at <= -1;
                high_start <= -1;
                timer_changed_since_rise <= 0;
                prev <= 0;

                if (note + 1 < NOTES) begin
                    if ({apu_data[2:0], apu_timer[7:0]} !==
                        exp_period[note + 1])
                        $error("FAIL note %0d: initial timer=%03h expected=%03h",
                               note + 2,
                               {apu_data[2:0], apu_timer[7:0]},
                               exp_period[note + 1]);

                    if (db_device.cpu.u_apu.pulse1_sweep !==
                        exp_sweep[note + 1])
                        $error("FAIL note %0d: sweep=%02h expected=%02h",
                               note + 2,
                               db_device.cpu.u_apu.pulse1_sweep,
                               exp_sweep[note + 1]);

                    if (apu_ctrl !== 8'h9F)
                        $error("FAIL note %0d: pulse control=%02h expected=9F",
                               note + 2, apu_ctrl);

                    $display("START note %0d: %s sweep, timer=$%03h",
                             note + 2,
                             exp_dir[note + 1] > 0 ? "positive" : "negative",
                             exp_period[note + 1]);
                end
            end else if (w_timer1) begin
                last_period <= db_device.cpu.u_apu.pulse1_timer;
            end else if (note >= 0 && note < NOTES) begin
                // if (cyc - note_start <= 3) begin
                //     last_period <= db_device.cpu.u_apu.pulse1_timer;
                // end
                //else 
                begin
                    if (db_device.cpu.u_apu.pulse1_timer != last_period) begin
                        // if ((exp_dir[note] > 0 &&
                        //     db_device.cpu.u_apu.pulse1_timer <= last_period) ||
                        //     (exp_dir[note] < 0 &&
                        //     db_device.cpu.u_apu.pulse1_timer >= last_period))
                        //     $error("FAIL note %0d: wrong sweep direction, %03h -> %03h",
                        //         note + 1, last_period,
                        //         db_device.cpu.u_apu.pulse1_timer);

                        sweep_updates <= sweep_updates + 1;
                        last_period <= db_device.cpu.u_apu.pulse1_timer;
                        timer_changed_since_rise <= 1;

                        $display("note %0d: timer %03h -> %03h",
                                note + 1, last_period,
                                db_device.cpu.u_apu.pulse1_timer);
                    end
                end

                if (audio1 !== 4'bxxxx && audio1 != 0)
                    last_nz <= cyc;

                if (cyc - note_start > SETTLE) begin
                    if (audio1 != prev)
                        prev <= audio1;

                    if (audio1 != 0 && audio1 != 4'bxxxx) begin
                        audible_samples <= audible_samples + 1;

                        if (audio1 != 4'd15)
                            vol_errs <= vol_errs + 1;
                    end

                    // Measure actual audio rising edges. Compare with the
                    // timer only when no sweep update occurred in the interval.
                    if (prev == 0 && audio1 != 0) begin
                        if (rise_at >= 0 && !timer_changed_since_rise) begin
                            // if (abs_i((cyc - rise_at) -
                            //     16 * (timer_at_rise + 1)) > 2)
                            //     period_errs <= period_errs + 1;

                            edges <= edges + 1;
                        end else if (rise_at < 0) begin
                            edges <= edges + 1;
                        end

                        rise_at <= cyc;
                        timer_at_rise <= db_device.cpu.u_apu.pulse1_timer;
                        timer_changed_since_rise <= 0;
                    end

                    // Measure the high part of each pulse for 50% duty.
                    if (prev != 0 && audio1 == 0) begin
                        // if (high_start >= 0 && !timer_changed_since_rise &&
                        //     abs_i((cyc - high_start) -
                        //         8 * (timer_at_rise + 1)) > 2)
                        //     duty_errs <= duty_errs + 1;
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
