
// NES APU noise channel: mode, volume, period, length counter, envelope.
//
// Register writes come decoded from apu2A03 (w_* strobes with data_in):
//   w_settings  $400C  ..LC VVVV  length halt / envelope loop, constant volume, volume
//   w_mode      $400E  N... PPPP  periodic noise mode, period
//   w_timer     $400F  LLLL L...  length counter 5 bits
module apu_noise (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        pulse_clk,      // APU clock (CPU clock / 2)
    input  logic        quarter_frame,  // envelope clock
    input  logic        half_frame,     // length counter
    input  logic        enabled,        // $4015 channel enable bit
    input  logic [7:0]  data_in,
    input  logic        w_settings,
    input  logic        w_mode,
    input  logic        w_timer,
    output logic        active,         // length counter != 0, for $4015 reads
    output logic [3:0]  audio
);

    logic [5:0]  settings;
    logic        mode;
    logic [7:0]  len_counter;
    logic [11:0]  noise_period;

    wire [3:0]  vol             = settings[3:0];
    wire        is_const        = settings[4];
    wire        halt            = settings[5];

    logic [7:0] noise_lengths[0:31];

    initial begin
        noise_lengths[0:15]  = {10, 254, 20, 2,  40, 4,  80, 6,  160, 8,  60, 10, 14, 12, 26, 14};
        noise_lengths[16:31] = {12, 16,  24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30};
    end

    logic [11:0] noise_periods[0:15];

    initial begin
        noise_periods[0:15]  = {4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068};
    end

    logic [11:0] counter;

    logic [14:0] lfsr;

    // timer and duty sequencer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 1;
            counter <= 0;
        end else begin
            if (counter == 0) begin
                lfsr <= {lfsr[0] ^ lfsr[mode ? 6 : 1], lfsr[14:1]};
                counter <= noise_period - 1;
            end else
                counter <= counter - 1'b1;
        end
    end


    logic       env_start;
    logic [3:0] env_divider;
    logic [3:0] env_decay_level;

    // registers, length counter, sweep and envelope
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            settings <= 0;
            mode <= 0;
            noise_period <= 0;
            len_counter <= 0;
            env_start <= 0;
            env_divider <= 0;
            env_decay_level <= 0;
        end else begin
            if (w_settings)
                settings <= data_in[5:0];
            if (w_mode) begin
                mode <= data_in[7];
                noise_period <= noise_periods[data_in[3:0]];
            end
            if (w_timer) begin
                env_start <= 1;
                if (enabled)
                    len_counter <= noise_lengths[data_in[7:3]];
            end

            if (half_frame && pulse_clk) begin
                if (!halt && len_counter != 0)
                    len_counter <= len_counter - 1;
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

    wire signal = !lfsr[0] & active;

    assign audio = (is_const ? vol : env_decay_level) & {4{signal}};

endmodule
