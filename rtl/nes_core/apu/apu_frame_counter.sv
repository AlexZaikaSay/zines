
// NES APU frame counter ($4017), advanced on apu_ce (CPU clock / 2).
//   mode 0 (4-step): quarter frames at steps 1-4, half frames at 2 and 4, IRQ after step 4
//   mode 1 (5-step): same clocks, step 5 is silent, no IRQ
// quarter_frame / half_frame / irq_latch are one clk pulses, generated on apu_ce.
module apu_frame_counter (
    input  logic clk,
    input  logic rst_n,
    input  logic apu_ce,
    input  logic mode,          // $4017 bit 7
    input  logic irq_inhibit,   // $4017 bit 6
    output logic quarter_frame, // envelope clock
    output logic half_frame,    // length counter and sweep clock
    output logic irq_latch      // frame IRQ request
);

    logic [14:0] frame_counter;

    localparam QUARTER_FRAME_1  = 3728;
    localparam QUARTER_FRAME_2  = 7456;
    localparam QUARTER_FRAME_3  = 11184;
    localparam QUARTER_FRAME_4  = 14914;
    localparam QUARTER_FRAME_5  = 18640;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_counter   <= 0;
            half_frame      <= 1'b0;
            quarter_frame   <= 1'b0;
            irq_latch       <= 1'b0;
        end else begin
            quarter_frame   <= 1'b0;  // every clock -> pulses last one clk
            half_frame      <= 1'b0;
            irq_latch       <= 1'b0;
            if (apu_ce) begin
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
                            irq_latch <= ~irq_inhibit;
                        end
                    end
                    QUARTER_FRAME_5: 
                        frame_counter <= 0;
                    default: ;
                endcase
            end
        end
    end

endmodule
