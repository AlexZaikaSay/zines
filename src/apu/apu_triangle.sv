
// NES APU triangle channel: timer, sequencer, length counter, linear counter.
//
// Register writes come decoded from apu2A03 (w_* strobes with data_in):
//   w_settings  $4008  CRRR RRRR  Linear counter control flag, Linear counter reload value
//   w_timer_lo  $400A  TTTT TTTT  timer low 8 bits
//   w_timer_hi  $400B  LLLL LTTT  length counter, timer high 3 bits
module apu_triangle (
    input  logic        clk,            // CPU clock
    input  logic        rst_n,
    input  logic        pulse_clk,      // APU clock (CPU clock / 2)
    input  logic        quarter_frame,  // linear counter clock
    input  logic        half_frame,     // length counter clock
    input  logic        enabled,        // $4015 channel enable bit
    input  logic [7:0]  data_in,
    input  logic        w_settings,
    input  logic        w_timer_lo,
    input  logic        w_timer_hi,
    output logic        active,         // length counter != 0, for $4015 reads
    output logic [3:0]  audio
);

    logic [7:0]  settings;
    logic [10:0] timer;
    logic [7:0]  len_counter;

    wire [6:0]  lin_counter_reload_value    = settings[6:0];
    wire        lin_counter_ctl             = settings[7];

    logic [6:0] lin_counter;

    logic [3:0] sequencer_volumes[0:31];

    initial begin
        sequencer_volumes[0:15]  = {15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,  0};
        sequencer_volumes[16:31] = {0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15};
    end

    logic [7:0] triangle_lengths[0:31];
    logic [4:0]  sequencer_timer;

    initial begin
        triangle_lengths[0:15]  = {10, 254, 20, 2,  40, 4,  80, 6,  160, 8,  60, 10, 14, 12, 26, 14};
        triangle_lengths[16:31] = {12, 16,  24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30};
    end

    logic [10:0] counter;

    // timer and 32-step sequencer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            sequencer_timer <= 0;
        end else begin
            if (counter == 0) begin
                // step only while both the linear and the length counter run
                if (lin_counter != 0 && len_counter != 0)
                    sequencer_timer <= sequencer_timer - 1;
                counter <= timer;
            end else
                counter <= counter - 1'b1;
        end
    end


    logic       lin_counter_reload;

    // registers, length counter and linear counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            settings <= 8'h00;
            timer <= 0;
            len_counter <= 0;
            lin_counter_reload <= 0;
            lin_counter <= 0;
        end else begin
            if (w_settings)
                settings <= data_in;
            if (w_timer_lo) begin
                timer[7:0] <= data_in;
            end
            if (w_timer_hi) begin
                timer[10:8] <= data_in[2:0];
                lin_counter_reload <= 1;
                if (enabled)
                    len_counter <= triangle_lengths[data_in[7:3]];
            end
            if (half_frame && pulse_clk) begin
                if (!lin_counter_ctl && len_counter != 0)
                    len_counter <= len_counter - 1;
            end
            if (quarter_frame && pulse_clk) begin
                if (lin_counter_reload)
                    lin_counter <= lin_counter_reload_value;
                else if (lin_counter != 0)
                    lin_counter <= lin_counter - 1;
                if (!lin_counter_ctl)
                    lin_counter_reload <= 0;
            end

            // Disabling the channel in $4015 clears the length counter
            if (!enabled)
                len_counter <= 0;
        end
    end

    assign active = (len_counter != 0);
    // a stopped triangle holds its last level instead of going silent
    assign audio = sequencer_volumes[sequencer_timer];

endmodule
