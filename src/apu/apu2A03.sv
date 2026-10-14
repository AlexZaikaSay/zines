`include "apu/apu_pulse.sv"
`include "apu/apu_frame_counter.sv"
`include "apu/apu_triangle.sv"

module apu2A03 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] addr,
    input  logic [7:0]  data_in,
    input  logic        rw,
    output logic [7:0]  data_out,
    output logic        irq_n,
    output logic [3:0]  audio1,
    output logic [3:0]  audio2,
    output logic [3:0]  audio3
);

    // internal registers and wires
    logic [1:0] control;    // $4017 bits 7:6: mode, IRQ inhibit

    wire mode           = control[1];
    wire fc_int_inhibit = control[0];

    logic pulse_clk;
    logic [2:0] control_en;   // $4015 channel enables

    // generate pulse clock from cpu clock
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pulse_clk <= 1'b0;
        end else begin
            if (clk) begin
                pulse_clk <= ~pulse_clk;
            end
        end
    end

    logic quarter_frame;
    logic half_frame;
    logic fc_int_latch;

    apu_frame_counter u_frame_counter (
        .pulse_clk,
        .rst_n,
        .mode,
        .irq_inhibit(fc_int_inhibit),
        .quarter_frame,
        .half_frame,
        .irq_latch(fc_int_latch)
    );

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

    // triangle channel
    localparam MEMIO_TRIANGLE_SETTING   = 16'h4008;
    localparam MEMIO_TRIANGLE_TIMER1    = 16'h400A;
    localparam MEMIO_TRIANGLE_TIMER2    = 16'h400B;

    localparam MEMIO_APU_STATUS         = 16'h4015;
    localparam MEMIO_CONTROL            = 16'h4017;

    wire r_apu_status           = (addr == MEMIO_APU_STATUS) && rw;
    wire w_apu_status           = (addr == MEMIO_APU_STATUS) && !rw;

    wire w_pulse1_settings      = (addr == MEMIO_PULSE1_SETTING) && !rw;
    wire w_pulse1_sweep         = (addr == MEMIO_PULSE1_SWEEP) && !rw;
    wire w_pulse1_timer1        = (addr == MEMIO_PULSE1_TIMER1) && !rw;
    wire w_pulse1_timer2        = (addr == MEMIO_PULSE1_TIMER2) && !rw;

    wire w_pulse2_settings      = (addr == MEMIO_PULSE2_SETTING) && !rw;
    wire w_pulse2_sweep         = (addr == MEMIO_PULSE2_SWEEP) && !rw;
    wire w_pulse2_timer1        = (addr == MEMIO_PULSE2_TIMER1) && !rw;
    wire w_pulse2_timer2        = (addr == MEMIO_PULSE2_TIMER2) && !rw;

    wire w_triangle_settings    = (addr == MEMIO_TRIANGLE_SETTING) && !rw;
    wire w_triangle_timer1      = (addr == MEMIO_TRIANGLE_TIMER1) && !rw;
    wire w_triangle_timer2      = (addr == MEMIO_TRIANGLE_TIMER2) && !rw;
    
    wire w_control          = (addr == MEMIO_CONTROL) && !rw;

    logic pulse1_active;
    logic pulse2_active;
    logic triangle_active;
    logic fc_int_flag;

    apu_pulse #(
        .ONES_COMPLEMENT(1'b1)
    ) u_pulse1 (
        .clk,
        .rst_n,
        .pulse_clk,
        .quarter_frame,
        .half_frame,
        .enabled(control_en[0]),
        .data_in,
        .w_settings(w_pulse1_settings),
        .w_sweep(w_pulse1_sweep),
        .w_timer_lo(w_pulse1_timer1),
        .w_timer_hi(w_pulse1_timer2),
        .active(pulse1_active),
        .audio(audio1)
    );

    apu_pulse #(
        .ONES_COMPLEMENT(1'b0)
    ) u_pulse2 (
        .clk,
        .rst_n,
        .pulse_clk,
        .quarter_frame,
        .half_frame,
        .enabled(control_en[1]),
        .data_in,
        .w_settings(w_pulse2_settings),
        .w_sweep(w_pulse2_sweep),
        .w_timer_lo(w_pulse2_timer1),
        .w_timer_hi(w_pulse2_timer2),
        .active(pulse2_active),
        .audio(audio2)
    );

    apu_triangle u_triangle (
        .clk,
        .rst_n,
        .pulse_clk,
        .quarter_frame,
        .half_frame,
        .enabled(control_en[2]),
        .data_in,
        .w_settings(w_triangle_settings),
        .w_timer_lo(w_triangle_timer1),
        .w_timer_hi(w_triangle_timer2),
        .active(triangle_active),
        .audio(audio3)
    );

    // $4015 / $4017 registers and frame IRQ flag
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fc_int_flag <= 1'b0;
            control_en <= 3'b000;
            control <= 2'b00;
        end else begin
            fc_int_flag <= fc_int_latch;
            if (r_apu_status)
                fc_int_flag <= 1'b0;
            if (w_apu_status)
                control_en <= data_in[2:0];
            if (w_control) begin
                if (data_in[6])
                    fc_int_flag <= 0;
                control <= data_in[7:6];
            end
        end
    end

    always_comb begin
        if (r_apu_status) begin
            // TODO: status for all channels
            data_out = {
                1'b0, 
                fc_int_flag, 
                1'b0, 
                1'b0, 
                1'b0, 
                triangle_active, 
                pulse2_active, 
                pulse1_active
            };
        end else begin
            data_out = 8'h00;
        end
    end

    assign irq_n = !fc_int_flag;

endmodule
