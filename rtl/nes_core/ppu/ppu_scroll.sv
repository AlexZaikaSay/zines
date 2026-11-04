// Scroll / VRAM address registers ("loopy" v, t, fine X and the $2005/$2006 write toggle).
// v is the only VRAM address of the PPU: the renderer walks it through the
// nametable while rendering, the CPU sets it through $2006 and steps it on $2007.
//   Rendering: coarse X steps at every tile edge, Y at dot 256, the horizontal
//   bits are reloaded from t at dot 257, the vertical ones at pre-render 280-304.
//   CPU writes are applied after the render updates of the same dot, so they win.
module ppu_scroll
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  ppu_timing_t timing,
    input  ppu_cpu_strobe_t strobe,         // $2000 / $2005 / $2006 / $2007 / $2002 accesses
    input  logic        increment_32,       // PPUCTRL bit 2: $2007 steps by 32
    input  logic [7:0]  cpu_data,
    output logic [14:0] v_addr,             // current VRAM address
    output logic [2:0]  fine_x
);

    logic [14:0] t_addr;                    // temporary VRAM address
    logic        write_toggle;

    wire data_access = strobe.wr_data || strobe.rd_data;

    wire [14:0] v_step = increment_32 ? 15'd32 : 15'd1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_addr       <= 0;
            t_addr       <= 0;
            fine_x       <= 0;
            write_toggle <= 1'b0;
        end else if (ce) begin
            // ---- render-side updates
            if (timing.rendering_active) begin
                if (timing.inc_y)
                    v_addr <= inc_y(inc_x(v_addr));
                else if (timing.tile_edge)
                    v_addr <= inc_x(v_addr);
                else if (timing.copy_h) begin
                    v_addr[4:0] <= t_addr[4:0];
                    v_addr[10]  <= t_addr[10];
                end else if (timing.copy_v) begin
                    v_addr[9:5]   <= t_addr[9:5];
                    v_addr[14:11] <= t_addr[14:11];
                end
            end

            // ---- CPU side (wins over the render-side updates)
            if (strobe.wr_ctrl)
                t_addr[11:10] <= cpu_data[1:0];

            if (strobe.wr_scroll) begin
                if (write_toggle) begin
                    t_addr[14:12] <= cpu_data[2:0];
                    t_addr[9:5]   <= cpu_data[7:3];
                end else begin
                    t_addr[4:0] <= cpu_data[7:3];
                    fine_x      <= cpu_data[2:0];
                end
                write_toggle <= ~write_toggle;
            end

            if (strobe.wr_addr) begin
                if (write_toggle) begin
                    t_addr[7:0] <= cpu_data;
                    v_addr      <= {t_addr[14:8], cpu_data};
                end else begin
                    t_addr[14:8] <= {1'b0, cpu_data[5:0]};
                end
                write_toggle <= ~write_toggle;
            end

            // While rendering the bus belongs to the renderer and $2007 is ignored
            if (data_access && !timing.rendering_active)
                v_addr <= v_addr + v_step;

            if (strobe.status_rd)
                write_toggle <= 1'b0;
        end
    end

    wire unused = &{1'b0, timing, strobe.oam_we};

endmodule
