
// NES APU pulse channel: timer, duty sequencer, length counter, envelope, sweep.
//
// Register writes come decoded from apu2A03 (w_* strobes with data_in):
//   w_settings  $4000/$4004  DDLC VVVV  duty, length halt / envelope loop, constant volume, volume
//   w_sweep     $4001/$4005  EPPP NSSS  sweep enable, period, negate, shift
//   w_timer_lo  $4002/$4006  timer low 8 bits
//   w_timer_hi  $4003/$4007  LLLL LTTT  length index, timer high 3 bits
module apu_pulse #(
    // Pulse 1 negates the sweep change with ones' complement, pulse 2 with two's complement
    parameter bit ONES_COMPLEMENT = 1'b0
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        pulse_clk,      // APU clock (CPU clock / 2)
    input  logic        quarter_frame,  // envelope clock
    input  logic        half_frame,     // length counter and sweep clock
    input  logic        enabled,        // $4015 channel enable bit
    input  logic [7:0]  data_in,
    input  logic        w_settings,
    input  logic        w_sweep,
    input  logic        w_timer_lo,
    input  logic        w_timer_hi,
    output logic        active,         // length counter != 0, for $4015 reads
    output logic [3:0]  audio
);

    logic [7:0]  settings;
    logic [7:0]  sweep;
    logic [10:0] timer;
    logic [7:0]  len_counter;

    wire [3:0]  vol             = settings[3:0];
    wire        is_const        = settings[4];
    wire        halt            = settings[5];
    wire [1:0]  width           = settings[7:6];

    wire [2:0]  sweep_shift     = sweep[2:0];
    wire        sweep_neg       = sweep[3];
    wire [2:0]  sweep_rate      = sweep[6:4];
    wire        sweep_enabled   = sweep[7];

    logic [7:0] duty_cycles[0:3];

    initial begin
        duty_cycles[0] = 8'b00000001;
        duty_cycles[1] = 8'b00000011;
        duty_cycles[2] = 8'b00001111;
        duty_cycles[3] = 8'b11111100;
    end

    logic [7:0] pulse_lengths[0:31];

    initial begin
        pulse_lengths[0] = 10;  pulse_lengths[1] = 254; pulse_lengths[2] = 20;  pulse_lengths[3] = 2;
        pulse_lengths[4] = 40;  pulse_lengths[5] = 4;   pulse_lengths[6] = 80;  pulse_lengths[7] = 6;
        pulse_lengths[8] = 160; pulse_lengths[9] = 8;   pulse_lengths[10] = 60; pulse_lengths[11] = 10;
        pulse_lengths[12] = 14; pulse_lengths[13] = 12; pulse_lengths[14] = 26; pulse_lengths[15] = 14;
        pulse_lengths[16] = 12;  pulse_lengths[17] = 16;  pulse_lengths[18] = 24;  pulse_lengths[19] = 18;
        pulse_lengths[20] = 48;  pulse_lengths[21] = 20;  pulse_lengths[22] = 96;  pulse_lengths[23] = 22;
        pulse_lengths[24] = 192; pulse_lengths[25] = 24;  pulse_lengths[26] = 72;  pulse_lengths[27] = 26;
        pulse_lengths[28] = 16;  pulse_lengths[29] = 28;  pulse_lengths[30] = 32;  pulse_lengths[31] = 30;
    end

    logic [10:0] counter;
    logic [2:0]  sequencer_timer;

    // timer and duty sequencer
    always_ff @(posedge pulse_clk or negedge rst_n) begin
        if (!rst_n) begin
            sequencer_timer <= 0;
            counter <= 0;
        end else begin
            if (counter == 0) begin
                sequencer_timer <= sequencer_timer - 1;
                if (sequencer_timer == 0)
                    sequencer_timer <= 7;
                counter <= timer;
            end else
                counter <= counter - 1'b1;
        end
    end

    // Sweep target is computed continuously from the current timer.
    wire [11:0] sweep_change = {1'b0, timer} >> sweep_shift;
    wire [11:0] sweep_target = sweep_neg ?
                               {1'b0, timer} - sweep_change - {11'd0, ONES_COMPLEMENT} :
                               {1'b0, timer} + sweep_change;

    // Channel is muted when the period is too small or the target overflows
    // (overflow is only possible when adding). Muting applies even if sweep is disabled.
    wire mute = (timer < 11'd8) || (!sweep_neg && sweep_target > 12'h7FF);

    logic       env_start;
    logic [3:0] env_divider;
    logic [3:0] env_decay_level;
    logic       sweep_reload;
    logic [2:0] sweep_counter;

    // registers, length counter, sweep and envelope
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            settings <= 8'h00;
            sweep <= 8'h00;
            timer <= 0;
            len_counter <= 0;
            env_start <= 0;
            env_divider <= 0;
            env_decay_level <= 0;
            sweep_reload <= 0;
            sweep_counter <= 0;
        end else begin
            if (w_settings)
                settings <= data_in;
            if (w_sweep) begin
                sweep <= data_in;
                sweep_reload <= 1;
            end
            if (w_timer_lo)
                timer[7:0] <= data_in;
            if (w_timer_hi) begin
                env_start <= 1;
                timer[10:8] <= data_in[2:0];
                // TODO: add reseting counter and sequence position
                if (enabled)
                    len_counter <= pulse_lengths[data_in[7:3]];
            end

            if (half_frame && pulse_clk) begin
                if (!halt && len_counter != 0)
                    len_counter <= len_counter - 1;

                if (sweep_counter == 0 && sweep_enabled && sweep_shift != 0 && !mute)
                    timer <= sweep_target[10:0];
                if (sweep_counter == 0 || sweep_reload) begin
                    sweep_counter <= sweep_rate;
                    sweep_reload <= 0;
                end else
                    sweep_counter <= sweep_counter - 1;
            end

            if (quarter_frame && pulse_clk) begin
                if (env_start == 0) begin
                    env_divider <= env_divider - 1;
                    if (env_divider == 0) begin
                        env_divider <= vol + 1;
                        if (env_decay_level != 0)
                            env_decay_level <= env_decay_level - 1;
                        else if (halt)
                            env_decay_level <= 15;
                    end
                end else begin
                    env_start <= 0;
                    env_decay_level <= 15;
                    env_divider <= vol + 1;
                end
            end

            // Disabling the channel in $4015 clears the length counter
            if (!enabled)
                len_counter <= 0;
        end
    end

    assign active = (len_counter != 0);

    wire signal = duty_cycles[width][sequencer_timer] & active & !mute;

    assign audio = (is_const ? vol : env_decay_level) & {4{signal}};

endmodule
