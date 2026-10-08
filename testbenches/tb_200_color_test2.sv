`include "cpu/mos6502.sv"
`include "cartridge/cartridge_sim.sv"
`include "ppu/ppu2C02.sv"

// Runs assets/color_test.nes on a minimal NES (6502 + NROM cartridge + PPU) and
// stores the last rendered frame as a 24-bit BMP for visual inspection.
//
// Clocking: `clk` is the PPU dot clock, the CPU runs at clk/3. PPU register
// accesses are presented to the PPU for a single `clk` per CPU cycle because
// the PPU has no chip-enable. $4014 (OAM DMA) is emulated here, stalling the CPU.
`define ROM_FILE "../assets/color_test.nes"
`define BMP_FILE "tb_200_color_test2"

module tb_200_color_test2;

    localparam string BMP_BASE   = `BMP_FILE;
    parameter [15:0] PC_START    = 16'h82C2; // RESET vector of color_test.nes
    parameter integer FRAMES     = 6;        // frames to run before saving the picture

    localparam integer WIDTH     = 256;
    localparam integer HEIGHT    = 240;
    localparam integer FRAME_CLK = 341 * 262;

    logic clk = 1'b0;
    logic rst_n;
    always #5 clk = ~clk;

    // ---------------------------------------------------------------- clock/phase
    logic [1:0] phase = 2'd0;
    logic       cpu_clk = 1'b0;
    logic       dma_start = 1'b0;
    logic       dma_active = 1'b0;
    logic [7:0] dma_page;
    logic [7:0] dma_cnt;

    always_ff @(posedge clk) begin
        phase   <= (phase == 2'd2) ? 2'd0 : phase + 2'd1;
        cpu_clk <= (phase == 2'd2) && !dma_active;
    end

    // ---------------------------------------------------------------- CPU
    logic [15:0] cpu_addr;
    logic [7:0]  cpu_data_out;
    logic [7:0]  cpu_data_in;
    logic        cpu_rw;
    logic        cpu_undef;
    logic        nmi_n;

    mos6502 #(.PC_START(PC_START)) cpu (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .nmi_n(nmi_n),
        .irq_n(1'b1),
        .data_in(cpu_data_in),
        .data_out(cpu_data_out),
        .addr(cpu_addr),
        .rw(cpu_rw),
        .undef(cpu_undef)
    );

    // 2 KiB internal RAM, mirrored through $1FFF
    logic [7:0] ram [0:2047];
    always_ff @(posedge cpu_clk)
        if (!cpu_rw && cpu_addr[15:13] == 3'b000)
            ram[cpu_addr[10:0]] <= cpu_data_out;

    wire sel_ram = (cpu_addr[15:13] == 3'b000);
    wire sel_ppu = (cpu_addr[15:13] == 3'b001);
    wire sel_cart = cpu_addr[15];

    logic [7:0] cart_cpu_data;
    logic [7:0] ppu_cpu_data;

    always_comb begin
        if (sel_cart)     cpu_data_in = cart_cpu_data;
        else if (sel_ram) cpu_data_in = ram[cpu_addr[10:0]];
        else if (sel_ppu) cpu_data_in = ppu_cpu_data;
        else              cpu_data_in = 8'h00; // APU / IO / open area
    end

    // ---------------------------------------------------------------- PPU register port
    wire ppu_strobe = (phase == 2'd1) && !dma_active;
    wire ppu_acc    = sel_ppu && ppu_strobe;

    // The PPU treats cpu_rw = 1 as a write; cpu_addr 0 with cpu_rw = 0 is a no-op.
    wire       ppu_cpu_rw   = dma_active ? 1'b1 : (ppu_acc && !cpu_rw);
    wire [2:0] ppu_cpu_addr = dma_active ? 3'd4 : (ppu_acc ? cpu_addr[2:0] : 3'd0);
    wire [7:0] ppu_cpu_din  = dma_active ? ram[{dma_page[2:0], dma_cnt}] : cpu_data_out;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dma_start  <= 1'b0;
            dma_active <= 1'b0;
            dma_cnt    <= 8'd0;
        end else begin
            if (ppu_strobe && !cpu_rw && cpu_addr == 16'h4014) begin
                dma_start <= 1'b1;
                dma_page  <= cpu_data_out;
            end
            if (phase == 2'd2 && dma_start) begin
                dma_start  <= 1'b0;
                dma_active <= 1'b1;
                dma_cnt    <= 8'd0;
            end
            if (dma_active) begin
                dma_cnt <= dma_cnt + 8'd1;
                if (dma_cnt == 8'd255)
                    dma_active <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------------- PPU
    logic [13:0] ppu_addr;
    logic [7:0]  ppu_data_out;
    logic [7:0]  ppu_data_in;
    logic        ppu_rd_n;
    logic        ppu_wr_n;
    logic [4:0]  video;

    ppu2C02 dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_rw(ppu_cpu_rw),
        .cpu_addr(ppu_cpu_addr),
        .cpu_data_in(ppu_cpu_din),
        .ppu_data_in(ppu_data_in),
        .cpu_data_out(ppu_cpu_data),
        .ppu_addr(ppu_addr),
        .ppu_data_out(ppu_data_out),
        .nmi_n(nmi_n),
        .ppu_rd_n(ppu_rd_n),
        .ppu_wr_n(ppu_wr_n),
        .ppu_cs_n(),
        .video(video)
    );

    wire ppu_rd = (ppu_rd_n === 1'b0);
    wire ppu_wr = (ppu_wr_n === 1'b0);

    // ---------------------------------------------------------------- Cartridge
    logic [7:0] cart_ppu_data;
    logic       ciram_a10;
    logic       ciram_ce;
    logic       cart_loaded;
    logic       cart_error;
    logic [7:0] cart_error_code;

    cartridge_sim #(.ROM_FILE(`ROM_FILE)) cart (
        .clk(clk),
        .cpu_addr(cpu_addr),
        .cpu_data_in(cpu_data_out),
        .cpu_data_out(cart_cpu_data),
        .cpu_rw(cpu_rw),
        .cpu_ce(sel_cart),
        .ppu_addr(ppu_addr),
        .ppu_rd(ppu_rd),
        .ppu_wr(ppu_wr),
        .ppu_data_in(ppu_data_out),
        .ppu_data_out(cart_ppu_data),
        .ciram_a10(ciram_a10),
        .ciram_ce(ciram_ce),
        .loaded(cart_loaded),
        .error(cart_error),
        .error_code(cart_error_code)
    );

    // ---------------------------------------------------------------- PPU-side memories
    logic [7:0] ciram [0:2047];
    logic [7:0] pal   [0:31];
    logic [7:0] ciram_dout;
    logic [7:0] pal_dout;
    logic [1:0] ppu_rsel; // 0: cartridge CHR, 1: nametable RAM, 2: palette RAM

    wire is_pal_addr = (ppu_addr[13:8] == 6'h3F);

    // $3F10/14/18/1C mirror $3F00/04/08/0C
    function automatic [4:0] pal_index(input [4:0] a);
        pal_index = (a[1:0] == 2'b00) ? {1'b0, a[3:0]} : a;
    endfunction

    always_ff @(posedge clk) begin
        ciram_dout <= ciram[{ciram_a10, ppu_addr[9:0]}];
        pal_dout   <= pal[pal_index(ppu_addr[4:0])];
        ppu_rsel   <= !ppu_addr[13] ? 2'd0 : (is_pal_addr ? 2'd2 : 2'd1);

        if (ppu_wr && ppu_addr[13]) begin
            if (is_pal_addr)
                pal[pal_index(ppu_addr[4:0])] <= ppu_data_out;
            else
                ciram[{ciram_a10, ppu_addr[9:0]}] <= ppu_data_out;
        end
    end

    always_comb begin
        case (ppu_rsel)
            2'd1:    ppu_data_in = ciram_dout;
            2'd2:    ppu_data_in = pal_dout;
            default: ppu_data_in = cart_ppu_data;
        endcase
    end

    // ---------------------------------------------------------------- Frame capture
    logic [23:0] nes_rgb [0:63];
    logic [23:0] frame   [0:WIDTH*HEIGHT-1];

    initial begin
        nes_rgb[8'h00]=24'h666666; nes_rgb[8'h01]=24'h002A88; nes_rgb[8'h02]=24'h1412A7; nes_rgb[8'h03]=24'h3B00A4;
        nes_rgb[8'h04]=24'h5C007E; nes_rgb[8'h05]=24'h6E0040; nes_rgb[8'h06]=24'h6C0600; nes_rgb[8'h07]=24'h561D00;
        nes_rgb[8'h08]=24'h333500; nes_rgb[8'h09]=24'h0B4800; nes_rgb[8'h0A]=24'h005200; nes_rgb[8'h0B]=24'h004F08;
        nes_rgb[8'h0C]=24'h00404D; nes_rgb[8'h0D]=24'h000000; nes_rgb[8'h0E]=24'h000000; nes_rgb[8'h0F]=24'h000000;
        nes_rgb[8'h10]=24'hADADAD; nes_rgb[8'h11]=24'h155FD9; nes_rgb[8'h12]=24'h4240FF; nes_rgb[8'h13]=24'h7527FE;
        nes_rgb[8'h14]=24'hA01ACC; nes_rgb[8'h15]=24'hB71E7B; nes_rgb[8'h16]=24'hB53120; nes_rgb[8'h17]=24'h994E00;
        nes_rgb[8'h18]=24'h6B6D00; nes_rgb[8'h19]=24'h388700; nes_rgb[8'h1A]=24'h0D9300; nes_rgb[8'h1B]=24'h008F32;
        nes_rgb[8'h1C]=24'h007C8D; nes_rgb[8'h1D]=24'h000000; nes_rgb[8'h1E]=24'h000000; nes_rgb[8'h1F]=24'h000000;
        nes_rgb[8'h20]=24'hFFFEFF; nes_rgb[8'h21]=24'h64B0FF; nes_rgb[8'h22]=24'h9290FF; nes_rgb[8'h23]=24'hC676FF;
        nes_rgb[8'h24]=24'hF36AFF; nes_rgb[8'h25]=24'hFE6ECC; nes_rgb[8'h26]=24'hFE8170; nes_rgb[8'h27]=24'hEA9E22;
        nes_rgb[8'h28]=24'hBCBE00; nes_rgb[8'h29]=24'h88D800; nes_rgb[8'h2A]=24'h5CE430; nes_rgb[8'h2B]=24'h45E082;
        nes_rgb[8'h2C]=24'h48CDDE; nes_rgb[8'h2D]=24'h4F4F4F; nes_rgb[8'h2E]=24'h000000; nes_rgb[8'h2F]=24'h000000;
        nes_rgb[8'h30]=24'hFFFEFF; nes_rgb[8'h31]=24'hC0DFFF; nes_rgb[8'h32]=24'hD3D2FF; nes_rgb[8'h33]=24'hE8C8FF;
        nes_rgb[8'h34]=24'hFBC2FF; nes_rgb[8'h35]=24'hFEC4EA; nes_rgb[8'h36]=24'hFECCC5; nes_rgb[8'h37]=24'hF7D8A5;
        nes_rgb[8'h38]=24'hE4E594; nes_rgb[8'h39]=24'hCFEF96; nes_rgb[8'h3A]=24'hBDF4AB; nes_rgb[8'h3B]=24'hB3F3CC;
        nes_rgb[8'h3C]=24'hB5EBF2; nes_rgb[8'h3D]=24'hB8B8B8; nes_rgb[8'h3E]=24'h000000; nes_rgb[8'h3F]=24'h000000;
    end

    integer frames_done = 0;
    integer clk_count   = 0;
    integer px;
    string  bmp_name;

    wire [8:0] scanline = dut.scanline;
    wire [8:0] cycle    = dut.cycle;

    always @(posedge clk) begin
        clk_count <= clk_count + 1;

        if (rst_n === 1'b1) begin
            if (scanline < HEIGHT && cycle >= 1 && cycle <= WIDTH) begin
                px = scanline * WIDTH + (cycle - 1);
                frame[px] <= nes_rgb[pal[pal_index(video)][5:0]];
            end

            if (scanline == HEIGHT && cycle == 0) begin
                frames_done <= frames_done + 1;
                $sformat(bmp_name, "%s_%0d.bmp", BMP_BASE, frames_done + 1);
                write_bmp(bmp_name);
                $display("tb_200_color_test: saved %s", bmp_name);
                if (frames_done + 1 == FRAMES) $finish;
            end
        end

        if (cpu_undef === 1'b1)
            $fatal(1, "tb_200_color_test: undefined opcode %02h at %04h", cpu_data_in, cpu_addr);
    end

    // 24-bit bottom-up BMP, rows are 768 bytes (already 4-byte aligned)
    task automatic put32(input integer fd, input [31:0] v);
        begin
            $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
        end
    endtask

    task automatic write_bmp(input string name);
        integer fd, x, y;
        logic [23:0] c;
        begin
            fd = $fopen(name, "wb");
            if (fd == 0)
                $fatal(1, "tb_200_color_test: cannot open %s", name);

            $fwrite(fd, "BM");
            put32(fd, 54 + WIDTH * HEIGHT * 3);
            put32(fd, 0);
            put32(fd, 54);
            put32(fd, 40);
            put32(fd, WIDTH);
            put32(fd, HEIGHT);
            $fwrite(fd, "%c%c%c%c", 8'h01, 8'h00, 8'h18, 8'h00);
            put32(fd, 0);
            put32(fd, WIDTH * HEIGHT * 3);
            put32(fd, 2835);
            put32(fd, 2835);
            put32(fd, 0);
            put32(fd, 0);

            for (y = HEIGHT - 1; y >= 0; y = y - 1) begin
                for (x = 0; x < WIDTH; x = x + 1) begin
                    c = frame[y * WIDTH + x];
                    if (^c === 1'bx) c = 24'h000000;
                    $fwrite(fd, "%c%c%c", c[7:0], c[15:8], c[23:16]); // B, G, R
                end
            end
            $fclose(fd);
        end
    endtask

    // ---------------------------------------------------------------- Reset / watchdog
    integer i;
    initial begin
        $dumpfile("tb_200_color_test2.vcd");
        $dumpvars(0, tb_200_color_test2);
        
        for (i = 0; i < 2048; i = i + 1) begin
            ram[i]   = 8'h00;
            ciram[i] = 8'h00;
        end
        for (i = 0; i < 32; i = i + 1) pal[i] = 8'h0F;
        for (i = 0; i < WIDTH * HEIGHT; i = i + 1) frame[i] = 24'h000000;

        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        #1 rst_n = 1'b1;
    end

    initial begin
        #1;
        repeat ((FRAMES + 4) * FRAME_CLK) @(posedge clk);
        $fatal(1, "tb_200_color_test: timeout before %0d frames completed", FRAMES);
    end

endmodule
