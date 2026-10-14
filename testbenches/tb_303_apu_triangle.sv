`include "boards/rp_devboard.sv"

/* verilator lint_off STMTDLY */

// Checks the triangle output of tests/asm/303_apu_triangle.ca65 against the 2A03 spec:
//   shape     = 32-step sequence 15,14..1,0,0,1..14,15,15,14.. (steps of +-1, 0 and 15 held twice)
//   frequency = CPU_HZ / (32 * (period + 1)): every step lasts period + 1 CPU cycles
//   stop      = the sequencer freezes (output keeps its last level) when either the
//               linear counter (reload * quarter-frame) or the length counter
//               (length table entry * half-frame) reaches zero, whichever is first
//   pulse 1/2 stay silent
module tb_303_apu_triangle;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/303_apu_triangle.tv";

    localparam QUARTER_FRAME = 7457;     // CPU cycles between linear counter clocks
    localparam HALF_FRAME    = 14915;    // CPU cycles between length counter clocks
    localparam RUN_CYCLES    = 3000000;
    localparam NOTES         = 3;

    // Expected notes: timer period, $4008 value, length table value
    integer exp_period [NOTES];
    integer exp_ctrl   [NOTES];
    integer exp_len    [NOTES];

    logic clk;
    logic rst_n;
    logic running;      // checks are enabled once reset is released
    logic [3:0] audio1;
    logic [3:0] audio2;
    logic [3:0] audio3;

    rp_devboard #(
        .MEM_FILE(MEM_FILE)
    ) db_device (
        .clk(clk),
        .rst_n(rst_n),
        .audio1(audio1),
        .audio2(audio2),
        .audio3(audio3)
    );

    wire        w_timer2 = db_device.cpu.u_apu.w_triangle_timer2;
    wire [7:0]  apu_data = db_device.cpu.u_apu.data_in;
    // timer period being written by $400B: data[2:0] high bits + $400A low byte
    wire [31:0] new_period = {21'd0, apu_data[2:0], db_device.cpu.u_apu.u_triangle.timer[7:0]};
    wire [31:0] apu_ctrl = {24'd0, db_device.cpu.u_apu.u_triangle.settings};
    wire        tri_active = db_device.cpu.u_apu.triangle_active;    // $4015 bit 2

    integer cyc;
    integer note;           // index of the running note, -1 before the first one
    integer note_start;
    integer len_end;        // cycle the length counter reached zero
    integer last_change;    // cycle of the last output step
    integer hold_start;     // cycle the current output level started
    logic   first_change;   // 1 until the first step of a note (its hold is partial)
    integer dir;            // +1 rising, -1 falling, 0 unknown
    integer steps;
    integer shape_errs;
    integer period_errs;
    logic [3:0] prev;
    logic [15:0] levels_seen;

    function automatic integer abs_i(input integer v);
        return v < 0 ? -v : v;
    endfunction

    function automatic integer min_i(input integer a, input integer b);
        return a < b ? a : b;
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

    task automatic finish_note(input integer idx);
        integer lin_stop, len_stop, expect_stop, played, step_len;
        begin
            if (idx >= 0) begin
                step_len = exp_period[idx] + 1;
                // Linear counter is reloaded on the first quarter frame after $400B and
                // then counts down once per quarter frame: stops within that window.
                lin_stop = (exp_ctrl[idx] & 'h7F) * QUARTER_FRAME + QUARTER_FRAME / 2;
                len_stop = exp_len[idx] * HALF_FRAME;
                expect_stop = min_i(lin_stop, len_stop);
                played = last_change - note_start;

                if (steps < 64)
                    $error("TEST FAILED: note %0d: only %0d steps, expected a running triangle", idx, steps);
                if (shape_errs != 0)
                    $error("TEST FAILED: note %0d: %0d steps break the triangle shape", idx, shape_errs);
                if (period_errs != 0)
                    $error("TEST FAILED: note %0d: %0d steps differ from %0d CPU cycles (%f Hz)",
                           idx, period_errs, step_len, 1789773.0 / (32 * step_len));
                if (levels_seen != 16'hFFFF)
                    $error("TEST FAILED: note %0d: levels seen %016b, expected all 0-15", idx, levels_seen);
                if (abs_i(played - expect_stop) > QUARTER_FRAME)
                    $error("TEST FAILED: note %0d: sequencer ran %0d cycles, expected ~%0d (%s counter)",
                           idx, played, expect_stop, lin_stop < len_stop ? "linear" : "length");
                if (len_end < 0 || abs_i(len_end - note_start - len_stop) > HALF_FRAME)
                    $error("TEST FAILED: note %0d: length counter ended after %0d cycles, expected ~%0d",
                           idx, len_end - note_start, len_stop);

                $display("note %0d: %0d Hz, %0d steps, stopped by %s counter after %0d cycles, length %0d cycles",
                         idx, 1789773 / (32 * step_len), steps,
                         lin_stop < len_stop ? "linear" : "length", played, len_end - note_start);
            end
        end
    endtask

    initial begin
        exp_period[0] = 'h07E; exp_ctrl[0] = 'h1F; exp_len[0] = 20;
        exp_period[1] = 'h07E; exp_ctrl[1] = 'h7F; exp_len[1] = 20;
        exp_period[2] = 'h02E; exp_ctrl[2] = 'h1F; exp_len[2] = 20;
        cyc = 0;
        note = -1;
        note_start = 0;
        len_end = -1;
        last_change = 0;
        hold_start = 0;
        first_change = 1;
        dir = 0;
        steps = 0;
        shape_errs = 0;
        period_errs = 0;
        prev = 0;
        levels_seen = 0;
    end

    initial begin
        $dumpfile("tb_303_apu_triangle.vcd");
        $dumpvars(0, tb_303_apu_triangle);
        rst_n = 0;
        running = 0;
        clk = 0;
        #1 rst_n = 0; #(CYCLE_LEN * 2); rst_n = 1; running = 1;
        for (integer i = 0; i < RUN_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
        end
        $error("TEST FAILED: timeout, only %0d notes started", note + 1);
        $finish;
    end

    always @(posedge clk) begin
        // Only the triangle is enabled by this program
        if (audio1 != 0)
            $error("FAIL: pulse 1 output %0d, expected silence", audio1);
        if (audio2 != 0)
            $error("FAIL: pulse 2 output %0d, expected silence", audio2);

        if (running) begin
            cyc <= cyc + 1;
            prev <= audio3;

            if (note >= 0 && len_end < 0 && cyc - note_start > 2 && !tri_active)
                len_end <= cyc;

            if (w_timer2) begin
                // The ca65 program writes $4008, $400A, then $400B (starts the note).
                // A final $400B write after the last note ends the test.
                finish_note(note);
                note <= note + 1;
                if (note + 1 == NOTES) begin
                    $display("tb_303_apu_triangle done");
                    $finish;
                end else begin
                    if (new_period !== exp_period[note + 1] || len_of(apu_data[7:3]) !== exp_len[note + 1])
                        $error("TEST FAILED: note %0d: period $%03h length %0d, expected $%03h and %0d",
                               note + 1, new_period, len_of(apu_data[7:3]), exp_period[note + 1], exp_len[note + 1]);
                    if (apu_ctrl !== exp_ctrl[note + 1])
                        $error("TEST FAILED: note %0d: $4008=%02h, expected %02h", note + 1, apu_ctrl, exp_ctrl[note + 1]);
                end
                note_start <= cyc;
                len_end <= -1;
                last_change <= cyc;
                first_change <= 1;
                steps <= 0;
                shape_errs <= 0;
                period_errs <= 0;
                levels_seen <= 0;
            end else if (note >= 0 && note < NOTES && audio3 != prev) begin
                // One sequencer step: +-1, turning around only at 0 and 15
                if (abs_i(32'(audio3) - 32'(prev)) != 1 ||
                    (prev == 4'd0 && audio3 != 4'd1) ||
                    (prev == 4'd15 && audio3 != 4'd14) ||
                    (prev != 4'd0 && prev != 4'd15 && dir != 0 &&
                     32'(audio3) - 32'(prev) != dir)) begin
                    shape_errs <= shape_errs + 1;
                    $error("FAIL note %0d: step %0d -> %0d breaks the triangle", note, prev, audio3);
                end
                dir <= 32'(audio3) - 32'(prev);

                // 0 and 15 are held for two steps, every other level for one
                if (!first_change &&
                    abs_i((cyc - hold_start) -
                          (prev == 4'd0 || prev == 4'd15 ? 2 : 1) * (exp_period[note] + 1)) > 1)
                    period_errs <= period_errs + 1;

                first_change <= 0;
                hold_start <= cyc;
                last_change <= cyc;
                steps <= steps + 1;
                levels_seen[audio3] <= 1'b1;
            end
        end
    end
endmodule

/* verilator lint_on STMTDLY */
