/* verilator lint_off STMTDLY */

// cartridge supervisor port: writes PRG and CHR through SV_*_WRITE, then reads every
// byte back through the CPU/PPU ports and through SV_*_READ (latency 2, held until
// the next read). A loader CHR read must win over a PPU read held low (paused NES).
module tb_106_cartridge_read_write;
    import zines_pkg::*;

    localparam integer PRG_BYTES   = 32768;
    localparam integer CHR_BYTES   = 8192;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic [3:0]  sv_sel;
    logic [14:0] sv_addr;
    logic [7:0]  sv_data_in;
    logic [7:0]  sv_data_out;

    logic [15:0] cpu_addr = 16'h0000;
    logic        cpu_ce_n = 1'b1;
    logic [7:0]  cpu_data_out;
    logic [13:0] ppu_addr = 14'h0000;
    logic        ppu_rd_n = 1'b1;
    logic [7:0]  ppu_data_out;
    logic        ciram_a10, ciram_ce_n;

    logic [7:0]  rdata;

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
        .sv_data_in(sv_data_in),
        .sv_addr(sv_addr),
        .sv_data_out(sv_data_out)
    );

    logic [7:0] prg [0:PRG_BYTES-1];
    logic [7:0] chr [0:CHR_BYTES-1];

    // One-clk command pulse on the supervisor port
    task automatic sv_cmd(input logic [3:0] sel, input logic [14:0] addr, input logic [7:0] data);
        @(posedge clk);
        sv_sel     <= sel;
        sv_addr    <= addr;
        sv_data_in <= data;
        @(posedge clk);
        sv_sel     <= SV_NONE;
    endtask

    task automatic write_byte(input logic [3:0] sel, input logic [14:0] addr, input logic [7:0] data);
        sv_cmd(sel, addr, data);
    endtask

    // Read pulse, then sv_data_out is valid 2 clks after the clk the cartridge saw it
    task automatic read_byte(input logic [3:0] sel, input logic [14:0] addr, output logic [7:0] data);
        sv_cmd(sel, addr, 8'h00);
        @(posedge clk);
        #1;
        data = sv_data_out;
    endtask

    task automatic write_prog();
        write_byte(SV_PRG_BANKS, 15'd0, 8'd2);
        for (int i = 0; i < PRG_BYTES; i++)
            write_byte(SV_PRG_WRITE, 15'(i), prg[i]);
    endtask

    task automatic write_chr();
        write_byte(SV_CHR_BANKS, 15'd0, 8'd1);
        for (int i = 0; i < CHR_BYTES; i++)
            write_byte(SV_CHR_WRITE, 15'(i), chr[i]);
    endtask

    // ---- normal NES access ----
    task automatic check_prg_cpu(input integer i);
        cpu_addr = 16'h8000 + 16'(i);
        cpu_ce_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        if (cpu_data_out !== prg[i])
            $fatal(1, "CPU PRG[%04h] expected %02h, got %02h", i, prg[i], cpu_data_out);
        cpu_ce_n = 1'b1;
    endtask

    task automatic check_chr_ppu(input integer i);
        ppu_addr = 14'(i);
        ppu_rd_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        if (ppu_data_out !== chr[i])
            $fatal(1, "PPU CHR[%04h] expected %02h, got %02h", i, chr[i], ppu_data_out);
        ppu_rd_n = 1'b1;
    endtask

    // ---- supervisor readback ----
    task automatic check_prg_loader(input integer i);
        read_byte(SV_PRG_READ, 15'(i), rdata);
        if (rdata !== prg[i])
            $fatal(1, "Loader PRG[%04h] expected %02h, got %02h", i, prg[i], rdata);
    endtask

    task automatic check_chr_loader(input integer i);
        read_byte(SV_CHR_READ, 15'(i), rdata);
        if (rdata !== chr[i])
            $fatal(1, "Loader CHR[%04h] expected %02h, got %02h", i, chr[i], rdata);
    endtask

    // sv_data_out keeps the byte while nothing else is read
    task automatic check_held(input logic [7:0] expected);
        repeat (5) @(posedge clk);
        #1;
        if (sv_data_out !== expected)
            $fatal(1, "sv_data_out not held: expected %02h, got %02h", expected, sv_data_out);
    endtask

    initial begin
        sv_sel     = SV_NONE;
        sv_addr    = '0;
        sv_data_in = '0;
        for (int i = 0; i < PRG_BYTES; i++)
            prg[i] = 8'(i ^ (i >> 8)) ^ 8'hA5;
        for (int i = 0; i < CHR_BYTES; i++)
            chr[i] = 8'(i ^ (i >> 8)) ^ 8'h5A;

        write_prog();
        write_chr();

        for (int i = 0; i < PRG_BYTES; i++)
            check_prg_cpu(i);
        for (int i = 0; i < CHR_BYTES; i++)
            check_chr_ppu(i);

        for (int i = 0; i < PRG_BYTES; i++)
            check_prg_loader(i);
        check_held(prg[PRG_BYTES-1]);
        for (int i = 0; i < CHR_BYTES; i++)
            check_chr_loader(i);
        check_held(chr[CHR_BYTES-1]);

        // Paused NES: the PPU keeps rd_n low on another address during loader reads
        ppu_addr = 14'h0123;
        ppu_rd_n = 1'b0;
        for (int i = 0; i < 256; i++)
            check_chr_loader(i * 31);
        check_held(chr[255 * 31]);
        ppu_rd_n = 1'b1;

        $display("tb_106_cartridge_read_write passed: %0d PRG + %0d CHR bytes, CPU/PPU and loader reads",
                 PRG_BYTES, CHR_BYTES);
        $finish;
    end

    initial begin
        repeat (1_000_000) @(posedge clk);
        $fatal(1, "Timed out");
    end
endmodule
