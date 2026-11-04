// PPUSTATUS flags and the NMI output.
//   vblank_flag:      set at line 241 dot 1, cleared at pre-render dot 1 and by a $2002 read
//   sprite0_hit_flag: set by the mixer, cleared at pre-render dot 1
//   sprite_overflow:  set by sprite evaluation, cleared at pre-render dot 1
// The frame events win over a $2002 read in the same dot.
module ppu_status
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  ppu_timing_t timing,
    input  ppu_cpu_strobe_t strobe,         // status_rd: CPU read of $2002
    input  logic        ovf_pulse,
    input  logic        sprite0_hit_now,
    input  logic        nmi_enable,         // PPUCTRL bit 7
    output logic        vblank_flag,
    output logic        sprite0_hit_flag,
    output logic        sprite_overflow,
    output logic        nmi_n
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vblank_flag      <= 1'b0;
            sprite0_hit_flag <= 1'b0;
            sprite_overflow  <= 1'b0;
        end else if (ce) begin
            if (strobe.status_rd)
                vblank_flag <= 1'b0;
            if (ovf_pulse)
                sprite_overflow <= 1'b1;
            if (sprite0_hit_now)
                sprite0_hit_flag <= 1'b1;

            if (timing.vblank_start) begin
                vblank_flag <= 1'b1;
            end else if (timing.vblank_end) begin
                vblank_flag      <= 1'b0;
                sprite0_hit_flag <= 1'b0;
                sprite_overflow  <= 1'b0;
            end
        end
    end

    assign nmi_n = ~(nmi_enable & vblank_flag);

    wire unused = &{1'b0, timing, strobe};

endmodule
