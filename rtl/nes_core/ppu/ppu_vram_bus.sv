// PPU VRAM bus: the only driver of ppu_addr / ppu_rd_n / ppu_wr_n / ppu_data_out,
// and the only module that knows when fetched data arrives.
//
// Rendering fetches work like the 2C02: each fetch takes two dots, the address is
// driven during the first one straight from the current v (and the latched tile
// number), the memory answers on its edge, and the data is taken at the end of
// the second dot. Per 8-dot tile, dots 1-2 nametable, 3-4 attribute, 5-6 pattern
// low, 7-8 pattern high; v steps after dot 8, so the next nametable address
// already sees the new coarse X. Sprites: dots 5-6 / 7-8 of each 8-dot slot in 257-320.
//
// Outside rendering the bus carries CPU $2007 accesses: address and strobes are
// registered for one dot, a read lands in the read buffer two dots later.
module ppu_vram_bus
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  ppu_timing_t timing,
    input  logic [8:0]  cycle,
    input  logic [14:0] v_addr,
    input  logic        bg_pattern_table,   // PPUCTRL bit 4
    input  logic [13:0] spr_pat_addr,       // low plane of slot spr_slot

    // CPU $2007 access
    input  ppu_cpu_strobe_t strobe,         // wr_data / rd_data: $2007
    input  logic [7:0]  cpu_data,
    output logic [7:0]  read_buffer,

    // palette RAM, on this bus inside the PPU
    input  logic        palette_sel,
    input  logic [7:0]  palette_rdata,
    output logic        palette_we,

    // external bus
    output logic [13:0] ppu_addr,
    output logic [7:0]  ppu_data_out,
    input  logic [7:0]  ppu_data_in,
    output logic        ppu_rd_n,
    output logic        ppu_wr_n,

    // fetched data, each valid for the one dot named by its strobe
    output ppu_fetch_t  fetch
);

    wire [2:0] mod8_cycle = cycle[2:0];
    wire [8:0] cycle_m1   = cycle - 9'd1;

    // ------ render fetch address, a function of the dot
    logic [7:0]  bg_nt;                     // tile number from the nametable fetch
    logic [7:0]  bg_lo;
    logic [1:0]  bg_at;
    logic [7:0]  bus_data;
    logic [13:0] render_addr;
    logic        render_rd;                 // first dot of a fetch

    wire bg_drive  = timing.rendering_active && timing.bg_fetch_win;
    wire spr_drive = timing.rendering_active && timing.spr_fetch_win;

    assign fetch.spr_slot = cycle_m1[5:3];  // dots 257-264 slot 0 .. 313-320 slot 7

    always_comb begin
        render_addr = 14'd0;
        render_rd   = 1'b0;
        if (bg_drive) begin
            render_rd = mod8_cycle[0];
            case (mod8_cycle)
                3'd1, 3'd2: render_addr = {2'b10, v_addr[11:0]};                         // $2000 | (v & $0FFF)
                3'd3, 3'd4: render_addr = {2'b10, v_addr[11:10], 4'b1111, v_addr[9:7], v_addr[4:2]};
                3'd5, 3'd6: render_addr = {1'b0, bg_pattern_table, bg_nt, 1'b0, v_addr[14:12]};
                default:    render_addr = {1'b0, bg_pattern_table, bg_nt, 1'b1, v_addr[14:12]};
            endcase
        end else if (spr_drive) begin
            render_rd   = mod8_cycle == 3'd5 || mod8_cycle == 3'd7;
            render_addr = (mod8_cycle == 3'd7 || mod8_cycle == 3'd0) ? (spr_pat_addr | 14'h0008)
                                                                     : spr_pat_addr;
        end
    end

    // ------ CPU side, registered
    logic [13:0] cpu_addr_q;
    logic        rd_n_q;
    logic        wr_n_q;
    logic [1:0]  rd_cnt;                    // $2007 read in flight

    wire render_drive = bg_drive || spr_drive;

    assign ppu_addr   = render_drive ? render_addr : cpu_addr_q;
    assign palette_we = !render_drive && !wr_n_q;
    assign ppu_rd_n   = (render_drive ? !render_rd : rd_n_q) || palette_sel;
    assign ppu_wr_n   = (render_drive || wr_n_q) || palette_sel;
    assign bus_data   = palette_sel ? palette_rdata : ppu_data_in;

    // ------ data arrival: end of the second dot of each fetch
    assign fetch.data          = bus_data;
    assign fetch.bg_lo         = bg_lo;
    assign fetch.bg_at         = bg_at;
    assign fetch.bg_tile_valid = bg_drive  && mod8_cycle == 3'd0;
    assign fetch.spr_lo_valid  = spr_drive && mod8_cycle == 3'd6;
    assign fetch.spr_hi_valid  = spr_drive && mod8_cycle == 3'd0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_addr_q   <= 0;
            ppu_data_out <= 0;
            rd_n_q       <= 1'b1;
            wr_n_q       <= 1'b1;
            rd_cnt       <= 0;
            read_buffer  <= 0;
            bg_nt        <= 0;
            bg_lo        <= 0;
            bg_at        <= 0;
        end else if (ce) begin
            rd_n_q <= 1'b1;
            wr_n_q <= 1'b1;

            if (rd_cnt != 0) begin
                rd_cnt <= rd_cnt - 1;
                if (rd_cnt == 1)
                    read_buffer <= bus_data;
            end

            if (bg_drive) begin
                case (mod8_cycle)
                    3'd2: bg_nt <= bus_data;
                    // 2-bit attribute of this 16x16 quadrant: bits {v[6], v[1], x} of the byte
                    3'd4: bg_at <= {bus_data[{v_addr[6], v_addr[1], 1'b1}],
                                    bus_data[{v_addr[6], v_addr[1], 1'b0}]};
                    3'd6: bg_lo <= bus_data;
                    default: ;
                endcase
            end

            // CPU $2007, ignored while rendering
            if (!timing.rendering_active) begin
                if (strobe.wr_data) begin
                    cpu_addr_q   <= v_addr[13:0];
                    ppu_data_out <= cpu_data;
                    wr_n_q       <= 1'b0;
                end else if (strobe.rd_data) begin
                    cpu_addr_q <= v_addr[13:0];
                    rd_n_q     <= 1'b0;
                    rd_cnt     <= 2;
                end
            end
        end
    end

    wire unused = &{1'b0, timing, strobe, cycle_m1[8:6], cycle_m1[2:0]};

endmodule
