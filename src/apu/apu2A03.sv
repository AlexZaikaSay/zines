

module apu2A03 (
    input  logic        clk,
    input  logic        cpu_clk,
    input  logic        rst_n,
    input  logic [15:0] addr,
    input  logic [7:0]  data_in,
    input  logic        rw,
    output logic [7:0]  data_out,
    output logic        irq
);

    // internal registers and wires
    logic [7:0] control;
    logic [7:0] pulse1_settings;
    logic [7:0] pulse2_settings;
    logic [10:0] pulse1_timer;
    logic [4:0] pulse1_len_counter;
    logic [10:0] pulse2_timer;
    logic [4:0] pulse2_len_counter;

    wire [3:0] pulse1_vol    = pulse1_settings[3:0];
    wire [1:0] pulse1_width  = pulse1_settings[7:6];

    wire pulse1_is_const     = pulse1_settings[4];
    wire pulse1_halt         = pulse1_settings[5];

    wire [3:0] pulse2_vol    = pulse2_settings[3:0];
    wire [1:0] pulse2_width  = pulse2_settings[7:6];

    wire pulse2_is_const     = pulse2_settings[4];
    wire pulse2_halt         = pulse2_settings[5];

    wire mode           = control[7];
    wire fc_int_inhibit = control[6];

    logic pulse_clk;

    // generate pulse clock from cpu clock
    always_ff @(posedge cpu_clk or negedge rst_n) begin
        if (!rst_n) begin
            pulse_clk <= 1'b0;
        end else begin
            if (cpu_clk) begin
                pulse_clk <= ~pulse_clk;
            end
        end
    end

    logic [7:0] duty_cycles[0:3];

    initial begin
        duty_cycles[0] = 8'b00000001;
        duty_cycles[1] = 8'b00000011;
        duty_cycles[2] = 8'b00001111;
        duty_cycles[3] = 8'b11111100;
    end

    logic [10:0]    pulse1_counter;
    logic [10:0]    pulse2_counter;
    logic [2:0]     pulse1_sequencer_timer;
    logic [2:0]     pulse2_sequencer_timer;

    // sequencer logic for pulse channels
    always_ff @(posedge pulse_clk or negedge rst_n) begin
        if (!rst_n) begin
            pulse1_sequencer_timer <= 0;
            pulse1_counter <= 0;
            pulse2_counter <= 0;
        end else begin
            if (pulse1_counter == 0) begin
                pulse1_sequencer_timer <= pulse1_sequencer_timer - 1;
                pulse1_counter <= pulse1_timer;
            end else
                pulse1_counter <= pulse1_counter - 1'b1;
            
            if (pulse2_counter == 0) begin
                pulse2_sequencer_timer <= pulse2_sequencer_timer - 1;
                pulse2_counter <= pulse2_timer;
            end else
                pulse2_counter <= pulse2_counter - 1'b1;

            if (pulse1_sequencer_timer == 0)
                pulse1_sequencer_timer <= 7;
            if (pulse2_sequencer_timer == 0)
                pulse2_sequencer_timer <= 7;
        end
    end

    wire pulse1_signal = duty_cycles[pulse1_width][pulse1_sequencer_timer];
    wire pulse2_signal = duty_cycles[pulse2_width][pulse2_sequencer_timer];


    logic [14:0] frame_counter;

    logic quarter_frame;
    logic half_frame;
    logic fc_int_latch;
    logic fc_int_flag;

    localparam QUARTER_FRAME_1  = 3728;
    localparam QUARTER_FRAME_2  = 7456;
    localparam QUARTER_FRAME_3  = 11184;
    localparam QUARTER_FRAME_4  = 14914;
    localparam QUARTER_FRAME_5  = 18640;


    // frame counter logic for APU
    always_ff @(posedge pulse_clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_counter <= 0;
            half_frame <= 1'b0;
            quarter_frame <= 1'b0;
            fc_int_latch <= 1'b0;
        end else begin
            // update frame counter logic here
            quarter_frame <= 1'b0;
            half_frame <= 1'b0;
            fc_int_latch <= 1'b0;
            frame_counter <= frame_counter + 1;
            case(frame_counter)
                QUARTER_FRAME_1,
                QUARTER_FRAME_3:
                    quarter_frame <= 1'b1;
                QUARTER_FRAME_2: begin
                    quarter_frame <= 1'b1;
                    half_frame <= 1'b1;
                end
                QUARTER_FRAME_4: begin
                    quarter_frame <= 1'b1;
                    half_frame <= 1'b1;
                    if (mode == 0) begin
                        frame_counter <= 0;
                        fc_int_latch <= ~fc_int_inhibit;
                    end
                end
                QUARTER_FRAME_5: 
                    frame_counter <= 0;
                default: ;
            endcase
        end
    end

    // pulse 1 channels
    localparam MEMIO_PULSE1_SETTING     = 16'h4000;
    localparam MEMIO_PULSE1_SWEEP       = 16'h4001;
    localparam MEMIO_PULSE1_TIMER1      = 16'h4002;
    localparam MEMIO_PULSE1_TIMER2      = 16'h4003;

    // pulse 2 channels
    localparam MEMIO_PULSE2_SETTING     = 16'h4004;
    localparam MEMIO_PULSE2_SWEEP       = 16'h4005;
    localparam MEMIO_PULSE2_TIMER1      = 16'h4006;
    localparam MEMIO_PULSE2_TIMER2      = 16'h4007;

    localparam MEMIO_APU_STATUS         = 16'h4015;
    localparam MEMIO_CONTROL            = 16'h4017;

    wire r_apu_status       = (addr == MEMIO_APU_STATUS) && rw;
    wire w_apu_status       = (addr == MEMIO_APU_STATUS) && !rw;

    wire w_pulse1_settings  = (addr == MEMIO_PULSE1_SETTING) && !rw;
    wire w_pulse1_sweep     = (addr == MEMIO_PULSE1_SWEEP) && !rw;
    wire w_pulse1_timer1    = (addr == MEMIO_PULSE1_TIMER1) && !rw;
    wire w_pulse1_timer2    = (addr == MEMIO_PULSE1_TIMER2) && !rw;

    wire w_pulse2_settings  = (addr == MEMIO_PULSE2_SETTING) && !rw;
    wire w_pulse2_sweep     = (addr == MEMIO_PULSE2_SWEEP) && !rw;
    wire w_pulse2_timer1    = (addr == MEMIO_PULSE2_TIMER1) && !rw;
    wire w_pulse2_timer2    = (addr == MEMIO_PULSE2_TIMER2) && !rw;
    
    wire w_control          = (addr == MEMIO_CONTROL) && !rw;
    

    // registers readers/writers and length counter management
    always_ff @(posedge cpu_clk or negedge rst_n) begin
        if (!rst_n) begin
            pulse1_settings <= 8'h00;
            pulse1_len_counter <= 0;
            pulse2_len_counter <= 0;
            fc_int_flag <= 1'b0;
        end else begin
            fc_int_flag <= fc_int_latch;
            if (r_apu_status) begin
                fc_int_flag <= 1'b0;
            end
            if (w_apu_status) begin
                if (data_in[0] == 1'b0)
                    pulse1_len_counter <= 0;
                if (data_in[1] == 1'b0)
                    pulse2_len_counter <= 0;
            end
            if (w_pulse1_settings) begin
                pulse1_settings <= data_in;
            end
            if (w_pulse1_sweep) begin
                ; // update pulse1 sweep register here
            end
            if (w_pulse1_timer1) begin
                pulse1_timer[7:0] <= data_in[7:0];
            end
            if (w_pulse1_timer2) begin
                pulse1_timer[10:8] <= data_in[2:0];
                pulse1_len_counter <= data_in[7:3];
            end
            if (w_pulse2_settings) begin
                pulse2_settings <= data_in;
            end
            if (w_pulse2_sweep) begin
                ; // update pulse2 sweep register here
            end
            if (w_pulse2_timer1) begin
               pulse2_timer[7:0] <= data_in[7:0];
            end
            if (w_pulse2_timer2) begin
                pulse2_timer[10:8] <= data_in[2:0];
                pulse2_len_counter <= data_in[7:3];
            end
            if (w_control) begin
                if (data_in[6])
                    fc_int_flag <= 0;
                control <= data_in;
            end
            if (half_frame && pulse_clk) begin
                if (pulse1_halt) begin
                    if (pulse1_len_counter != 0)
                        pulse1_len_counter <= pulse1_len_counter - 1;
                end
                if (pulse2_halt) begin
                    if (pulse2_len_counter != 0)
                        pulse2_len_counter <= pulse2_len_counter - 1;
                end
            end
        end
    end


    assign irq = !fc_int_flag;

    always_comb begin
        if (r_apu_status) begin
            // TODO: status for all channels
            data_out = {
                1'b0, 
                fc_int_flag, 
                1'b0, 
                1'b0, 
                1'b0, 
                1'b0, 
                pulse2_len_counter != 0, 
                pulse1_len_counter != 0
            };
        end else begin
            data_out = 8'h00;
        end
    end

endmodule
