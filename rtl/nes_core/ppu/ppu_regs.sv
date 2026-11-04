// CPU register port $2000-$2007: address decode, PPUCTRL, PPUMASK, OAMADDR and
// the registered read data. The other registers live with their owners and get
// one-clock strobes from here: scroll ($2005/$2006, t/v), OAM ($2004),
// VRAM bus ($2007), status ($2002).
module ppu_regs
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  logic        ppu_cs_n,
    input  logic        cpu_rw,             // 1 = read
    input  logic [2:0]  cpu_addr,
    input  logic [7:0]  cpu_data_in,
    output logic [7:0]  cpu_data_out,

    // read sources
    input  logic        vblank_flag,
    input  logic        sprite0_hit_flag,
    input  logic        sprite_overflow,
    input  logic [7:0]  oam_rdata,
    input  logic [7:0]  read_buffer,        // $2007 read buffer

    output logic [7:0]  ppu_ctrl,
    output logic [7:0]  ppu_mask,
    output logic [7:0]  oam_addr,

    // strobes, one clk per access
    output ppu_cpu_strobe_t strobe
);

    // An access is taken on a PPU dot; while the PPU is paused (ce = 0) it waits
    wire cpu_read  = ce && cpu_rw && !ppu_cs_n;
    wire cpu_write = ce && !cpu_rw && !ppu_cs_n;

    assign strobe.wr_ctrl   = cpu_write && cpu_addr == PPUCTRL;
    assign strobe.wr_scroll = cpu_write && cpu_addr == PPUSCROLL;
    assign strobe.wr_addr   = cpu_write && cpu_addr == PPUADDR;
    assign strobe.wr_data   = cpu_write && cpu_addr == PPUDATA;
    assign strobe.oam_we    = cpu_write && cpu_addr == OAMDATA;
    assign strobe.rd_data   = cpu_read  && cpu_addr == PPUDATA;
    assign strobe.status_rd = cpu_read  && cpu_addr == PPUSTATUS;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ppu_ctrl     <= 0;
            ppu_mask     <= 0;
            oam_addr     <= 0;
            cpu_data_out <= 0;
        end else if (cpu_write) begin
            case (cpu_addr)
                PPUCTRL: ppu_ctrl <= cpu_data_in;
                PPUMASK: ppu_mask <= cpu_data_in;
                OAMADDR: oam_addr <= cpu_data_in;
                OAMDATA: oam_addr <= oam_addr + 1;      // the data goes to ppu_oam
                default: ;
            endcase
        end else if (cpu_read) begin
            case (cpu_addr)
                PPUSTATUS: cpu_data_out <= {vblank_flag, sprite0_hit_flag, sprite_overflow, 5'b00000};
                OAMDATA:   cpu_data_out <= oam_rdata;
                PPUDATA:   cpu_data_out <= read_buffer;
                default: ;
            endcase
        end
    end

endmodule
