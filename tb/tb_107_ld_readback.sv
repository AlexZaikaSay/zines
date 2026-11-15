/* verilator lint_off STMTDLY */

// Supervisor loader readback on the real OSD CPU bus: supervisor + cartridge run
// tests/107_ld_readback.tv, which writes PRG/CHR through LD_DATA and reads them back
// through LD_DATA (prefetch, auto-increment, sta LD_ADDR0 right before lda LD_DATA,
// back-to-back reads). The program leaves its result in supervisor RAM $0200.
module tb_107_ld_readback;
    import zines_pkg::*;

    localparam string ROM_FILE = "tests/107_ld_readback.tv";

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic [7:0] rst_cnt = 8'd0;
    logic       rst_n;
    always @(posedge clk)
        if (rst_cnt != 8'd50) rst_cnt <= rst_cnt + 8'd1;
    assign rst_n = (rst_cnt == 8'd50);

    logic [3:0]  sv_sel;
    logic [14:0] sv_addr;
    logic [7:0]  sv_data_in;
    logic [7:0]  sv_data_out;
    logic        sup_undef;

    supervisor #(
        .ROM_FILE(ROM_FILE)
    ) u_sup (
        .clk(clk),
        .rst_n(rst_n),
        .pad_buttons(8'h00),
        .nes_reset(),
        .nes_pause(),
        .nes_paused(1'b1),
        .sv_sel(sv_sel),
        .sv_addr(sv_addr),
        .sv_data_in(sv_data_in),
        .sv_data_out(sv_data_out),
        .osd_text_we(),
        .osd_attr_we(),
        .osd_waddr(),
        .osd_wdata(),
        .sd_clk(),
        .sd_cmd(),
        .sd_dat0(1'b1),
        .sd_cs_n(),
        .sd_cd_n(1'b1),
        .undef(sup_undef)
    );

    cartridge u_cart (
        .clk(clk),
        .cpu_addr(16'h0000),
        .cpu_data_out(),
        .cpu_rw(1'b1),
        .cpu_ce_n(1'b1),
        .ppu_addr(14'h0000),
        .ppu_rd_n(1'b1),
        .ppu_wr_n(1'b1),
        .ppu_data_in(8'h00),
        .ppu_data_out(),
        .ciram_a10(),
        .ciram_ce_n(),
        .sv_sel(sv_sel),
        .sv_data_in(sv_data_in),
        .sv_addr(sv_addr),
        .sv_data_out(sv_data_out)
    );

    logic [7:0] result;
    assign result = u_sup.u_ram.data[13'h0200];

    initial begin
        u_sup.u_ram.data[13'h0200] = 8'h00;
    end

    initial begin
        wait (rst_n);
        while (result == 8'h00 && !sup_undef)
            @(posedge clk);
        if (sup_undef)
            $fatal(1, "tb_107: supervisor CPU hit an undefined opcode");

        // Program result first: a failed step leaves the later steps unwritten
        if (result !== 8'h01)
            $fatal(1, "tb_107: step %0d failed at index %02h, read %02h",
                   result & 8'h7F, u_sup.u_ram.data[13'h0201], u_sup.u_ram.data[13'h0202]);

        // The writes also landed in the cartridge memories
        for (int i = 0; i < 256; i++) begin
            if (u_cart.prg_mem[i] !== 8'(i ^ 8'hA5))
                $fatal(1, "tb_107: prg_mem[%02h] = %02h, expected %02h", i, u_cart.prg_mem[i], 8'(i ^ 8'hA5));
            if (u_cart.chr_rom[i] !== 8'(i ^ 8'h5A))
                $fatal(1, "tb_107: chr_rom[%02h] = %02h, expected %02h", i, u_cart.chr_rom[i], 8'(i ^ 8'h5A));
        end

        $display("tb_107_ld_readback passed: LD_DATA readback of PRG and CHR, page crossing, back-to-back reads");
        $finish;
    end

    initial begin
        repeat (200_000) @(posedge clk);
        $fatal(1, "tb_107: timed out, result %02h", result);
    end
endmodule
