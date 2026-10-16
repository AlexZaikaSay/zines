// Real NES controller support, decoupled from CPU timing.
//
// nes_pad_poller drives the pad's LATCH/CLK itself, slowly (default 12 us latch,
// 6 us clock half-periods, ~1 kHz), and samples DO late in each half-period. Some
// clone pads (e.g. CSH-8088-3 at 3.3 V) do not follow the console's ~0.5 us clock
// pulses: each button then also shows up in the previous bit.
//
// nes_pad_port answers the CPU's $4016/$4017 accesses like a CD4021: while OUT0
// (strobe) is high it keeps loading the buttons and returns A; each read returns the
// current bit and shifts when /OE rises; after 8 reads it returns 1.
//
// Bit order everywhere: 0 A, 1 B, 2 Select, 3 Start, 4 Up, 5 Down, 6 Left, 7 Right;
// 1 = pressed.
module nes_pad_poller #(
    parameter integer CLK_HZ      = 5_361_702,
    parameter integer POLL_HZ     = 1_000,
    parameter integer LATCH_NS    = 12_000,
    parameter integer HALF_NS     = 6_000,
    parameter bit     ACTIVE_LOW  = 1'b1         // DO low = pressed (original pad)
) (
    input  logic       clk,
    input  logic       rst_n,
    output logic       pad_latch,
    output logic       pad_clk,
    input  logic       pad_data,                 // already synchronized to clk
    output logic [7:0] buttons
);
    localparam integer POLL_CYCLES  = CLK_HZ / POLL_HZ;
    localparam integer LATCH_CYCLES = (CLK_HZ / 1000) * LATCH_NS / 1_000_000 + 1;
    localparam integer HALF_CYCLES  = (CLK_HZ / 1000) * HALF_NS / 1_000_000 + 1;

    typedef enum logic [2:0] {IDLE, LATCH, SETTLE, CLK_LOW, TAIL_LOW} state_t;

    state_t      state;
    logic [31:0] timer;
    logic [31:0] poll_timer;
    logic [2:0]  bit_index;
    logic [7:0]  shift;

    wire pressed = pad_data ^ ACTIVE_LOW;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            timer      <= 32'd0;
            poll_timer <= 32'd0;
            bit_index  <= 3'd0;
            shift      <= 8'h00;
            buttons    <= 8'h00;
            pad_latch  <= 1'b0;
            pad_clk    <= 1'b1;
        end
        else begin
            poll_timer <= (poll_timer == 32'(POLL_CYCLES - 1)) ? 32'd0 : poll_timer + 32'd1;
            if (timer != 32'd0)
                timer <= timer - 32'd1;

            case (state)
                IDLE:
                    if (poll_timer == 32'd0) begin
                        pad_latch <= 1'b1;
                        timer     <= 32'(LATCH_CYCLES);
                        state     <= LATCH;
                    end

                LATCH:
                    if (timer == 32'd0) begin
                        pad_latch <= 1'b0;
                        timer     <= 32'(HALF_CYCLES);
                        bit_index <= 3'd0;
                        state     <= SETTLE;
                    end

                // DO has been stable for a full half-period: take the current bit
                SETTLE:
                    if (timer == 32'd0) begin
                        shift[bit_index] <= pressed;
                        pad_clk          <= 1'b0;
                        timer            <= 32'(HALF_CYCLES);
                        if (bit_index == 3'd7) begin
                            buttons <= {pressed, shift[6:0]};
                            state   <= TAIL_LOW;
                        end
                        else begin
                            state   <= CLK_LOW;
                        end
                    end

                // Rising CLK shifts the pad to the next bit
                CLK_LOW:
                    if (timer == 32'd0) begin
                        pad_clk   <= 1'b1;
                        timer     <= 32'(HALF_CYCLES);
                        bit_index <= bit_index + 3'd1;
                        state     <= SETTLE;
                    end

                // 8th clock, as the console gives after 8 reads: the pad moves past
                // Right to its "not pressed" fill, otherwise a held Right leaks into
                // the A bit of the next poll on the CSH-8088-3
                TAIL_LOW:
                    if (timer == 32'd0) begin
                        pad_clk <= 1'b1;
                        state   <= IDLE;
                    end

                default:
                    state <= IDLE;
            endcase
        end
    end

endmodule


module nes_pad_port (
    input  logic       clk,                      // faster than the CPU clock (ppu_clk)
    input  logic       rst_n,
    input  logic       strobe,                   // CPU OUT0 ($4016 bit 0)
    input  logic       oe_n,                     // CPU /OE for this port, low during a read
    input  logic [7:0] buttons,
    output logic       data                      // D0, 1 = pressed
);
    logic [7:0] shift;
    logic       oe_n_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift  <= 8'hFF;
            oe_n_q <= 1'b1;
        end
        else begin
            oe_n_q <= oe_n;
            if (strobe)
                shift <= buttons;
            else if (oe_n && !oe_n_q)            // read finished
                shift <= {1'b1, shift[7:1]};
        end
    end

    assign data = strobe ? buttons[0] : shift[0];

endmodule
