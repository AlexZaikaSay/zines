/* verilator lint_off STMTDLY */

// loads cartridge using manual loading commands writing image at LBA 0.
// Checks every PRG and CHR byte and the nametable mirroring against the file.
module tb_106_cartridge_read_write;
    import zines_pkg::*;

    localparam integer PRG_BYTES   = 32768;
    localparam integer CHR_BYTES   = 8192;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic [3:0]  sv_sel;
    logic [14:0] sv_addr;
    logic [7:0]  sv_data;

    logic [15:0] cpu_addr = 16'h0000;
    logic        cpu_ce_n = 1'b1;
    logic [7:0]  cpu_data_out;
    logic [13:0] ppu_addr = 14'h0000;
    logic        ppu_rd_n = 1'b1;
    logic [7:0]  ppu_data_out;
    logic        ciram_a10, ciram_ce_n;


    cartridge u_cartridge (
        .clk(clk),
        .cpu_addr(cpu_addr),
        .cpu_data_out(cpu_data_out),
        .cpu_rw(1'b1),
        .cpu_ce_n(cpu_ce_n),
        .ppu_addr(ppu_addr),
        .ppu_rd_n(ppu_rd_n),
        .ppu_wr_n(1'b1),
        .ppu_data_in(8'h00),
        .ppu_data_out(ppu_data_out),
        .ciram_a10(ciram_a10),
        .ciram_ce_n(ciram_ce_n),
        .sv_sel(sv_sel),
        .sv_data_in(sv_data),
        .sv_addr(sv_addr)
    );

    logic [7:0] prg [0:PRG_BYTES-1];
    logic [7:0] chr [0:CHR_BYTES-1];

    task automatic write_byte(input logic [2:0] sel, input logic [14:0] addr, input logic [7:0] data);
        @(posedge clk);
        sv_sel      <= sel;
        sv_addr     <= addr;
        sv_data     <= data;
        @(posedge clk);
        sv_sel      <= SV_NONE;
    endtask

    task automatic write_prog(); 
        write_byte(SV_PRG_BANKS, 0, 2);
        for (int i = 0; i < PRG_BYTES; i++)
            write_byte(SV_PRG_WRITE, i, prg[i]);
    endtask

    task automatic write_chr();
        write_byte(SV_CHR_BANKS, 0, 1);
        for (int i = 0; i < CHR_BYTES; i++)
            write_byte(SV_CHR_WRITE, i, chr[i]);
    endtask

    task automatic check_prg_byte(input logic [15:0] a, input integer file_offset);
        cpu_addr = a;
        cpu_ce_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        if (cpu_data_out !== prg[file_offset])
            $fatal(1, "PRG[%04h] expected %02h, got %02h", a, prg[file_offset], cpu_data_out);
        cpu_ce_n = 1'b1;
    endtask

    task automatic check_chr_byte(input logic [13:0] a, input integer i);
        ppu_addr = a;
        ppu_rd_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        if (ppu_data_out !== chr[i])
            $fatal(1, "CHR[%04h] expected %02h, got %02h", a, chr[i], ppu_data_out);
        ppu_rd_n = 1'b1;
    endtask

    task automatic check_prog();
        for (int i = 0; i < PRG_BYTES; i++)
            check_prg_byte(16'h8000 + i, i);
    endtask

    task automatic check_chr();
        for (int i = 0; i < CHR_BYTES; i++)
            check_chr_byte(i, i);
    endtask

    initial begin
        sv_sel = SV_NONE;
        for (int i = 0; i < PRG_BYTES; i++)
            prg[i] = i ^ (i >> 8) ^ 8'hA5;
        for (int i = 0; i < CHR_BYTES; i++)
            chr[i] = i ^ (i >> 8) ^ 8'h5A;
        write_prog();
        write_chr();
        check_prog();
        check_chr();
        $display("cartridge_read_write test passed: %0d PRG + %0d CHR bytes",
                PRG_BYTES, CHR_BYTES);
        $finish;
    end

    initial begin
        repeat (300_000) @(posedge clk);
        $fatal(1, "Timed out");
    end
endmodule
