// NES APU mix -> 48 kHz PCM samples in the pixel clock domain.
//
// The sample strobe is derived from the pixel clock (HDMI audio clock regeneration
// is defined relative to it). Each strobe toggles a request into the PPU domain,
// which captures the mix into a holding register and toggles an acknowledge back;
// the holding register is stable whenever the pixel side reads it.
//
// Mix: linear approximation of the APU DAC (nesdev "Linear Approximation"),
// pulse 0.00752, triangle 0.00851, noise 0.00494 per step, scaled by 65536.
// The result is 0..28020, a positive signed 16-bit value.
module nes_audio_sampler #(
    parameter integer PIXEL_CLK_HZ = 25_200_000,
    parameter integer SAMPLE_RATE  = 48_000
) (
    input  logic        ppu_clk,
    input  logic [3:0]  audio1,         // pulse 1
    input  logic [3:0]  audio2,         // pulse 2
    input  logic [3:0]  audio3,         // triangle
    input  logic [3:0]  audio4,         // noise

    input  logic        pix_clk,
    input  logic        pix_rst_n,
    output logic [15:0] sample,
    output logic        sample_valid
);
    localparam integer DIVIDER = PIXEL_CLK_HZ / SAMPLE_RATE;

    logic [15:0] div_cnt;
    logic        req;           // pixel domain, toggles once per sample
    logic [2:0]  ack_sync;

    // ----------------------------------------------------------------
    // PPU domain: mixer and holding register
    // ----------------------------------------------------------------
    wire [15:0] mix = 16'd493 * ({12'd0, audio1} + {12'd0, audio2}) +
                      16'd558 * {12'd0, audio3} +
                      16'd324 * {12'd0, audio4};

    // Power-up values instead of a reset: this side has no reset in the PPU domain
    /* verilator lint_off PROCASSINIT */
    logic [2:0]  req_sync = 3'd0;
    logic        ack      = 1'b0;
    logic [15:0] hold     = 16'd0;
    /* verilator lint_on PROCASSINIT */

    always_ff @(posedge ppu_clk) begin
        req_sync <= {req_sync[1:0], req};
        if (req_sync[2] != req_sync[1]) begin
            hold <= mix;
            ack  <= ~ack;
        end
    end

    // ----------------------------------------------------------------
    // Pixel domain: sample strobe and handshake
    // ----------------------------------------------------------------
    always_ff @(posedge pix_clk or negedge pix_rst_n) begin
        if (!pix_rst_n) begin
            div_cnt      <= 16'd0;
            req          <= 1'b0;
            ack_sync     <= 3'd0;
            sample       <= 16'd0;
            sample_valid <= 1'b0;
        end
        else begin
            if (div_cnt == 16'(DIVIDER - 1)) begin
                div_cnt <= 16'd0;
                req     <= ~req;
            end
            else begin
                div_cnt <= div_cnt + 16'd1;
            end

            ack_sync     <= {ack_sync[1:0], ack};
            sample_valid <= (ack_sync[2] != ack_sync[1]);
            if (ack_sync[2] != ack_sync[1])
                sample <= hold;
        end
    end

endmodule
