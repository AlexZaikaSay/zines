// One sprite output unit: holds the pattern bits, palette and priority of one
// secondary-OAM slot for the current line and shifts its pixels out.
//   load_lo / load_hi load the low / high pattern byte fetched for this slot
//   (horizontally flipped when attr[6] is set); load_lo also latches X and attributes.
//   An empty slot (!valid) loads a transparent pattern.
//   shift: one visible dot. The X counter counts down first, then the pattern shifts.
module ppu_sprite_unit
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  logic        active,         // rendering_active: nothing changes otherwise
    input  logic        load_lo,
    input  logic        load_hi,
    input  logic        shift,
    input  logic        valid,          // this slot holds a sprite on the current line
    input  logic [7:0]  pattern,        // fetched pattern byte (VRAM bus)
    input  logic [7:0]  x,
    input  logic [7:0]  attr,
    input  logic        is0_in,         // the sprite is OAM sprite 0
    output logic [1:0]  pixel,          // 0 = transparent
    output logic [1:0]  palette,
    output logic        behind,         // behind the background
    output logic        is0
);

    logic [7:0] pat_lo;
    logic [7:0] pat_hi;
    logic [7:0] x_cnt;                  // X delay counter

    wire [7:0] pattern_flipped = attr[6] ? reverse_byte(pattern) : pattern;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pat_lo  <= 8'd0;
            pat_hi  <= 8'd0;
            x_cnt   <= 8'd0;
            palette <= 2'd0;
            behind  <= 1'b0;
            is0     <= 1'b0;
        end else if (ce && active) begin
            if (load_lo) begin
                if (valid) begin
                    pat_lo  <= pattern_flipped;
                    x_cnt   <= x;
                    palette <= attr[1:0];
                    behind  <= attr[5];
                    is0     <= is0_in;
                end else begin
                    pat_lo  <= 8'd0;
                end
            end else if (load_hi) begin
                pat_hi <= valid ? pattern_flipped : 8'd0;
            end else if (shift) begin
                if (x_cnt != 0) begin
                    x_cnt <= x_cnt - 8'd1;
                end else begin
                    pat_lo <= {pat_lo[6:0], 1'b0};
                    pat_hi <= {pat_hi[6:0], 1'b0};
                end
            end
        end
    end

    assign pixel = (x_cnt == 0) ? {pat_hi[7], pat_lo[7]} : 2'b00;

    wire unused = &{1'b0, attr[7], attr[4:2]};

endmodule
