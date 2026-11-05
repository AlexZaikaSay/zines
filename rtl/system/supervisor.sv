// Supervisor: the OSD 6502 and everything on its bus.
//
//   $0000-$1FFF  work RAM 8 KiB             $4008/$4009  pad: buttons / changed
//   $2000-$27FF  OSD text   (osd_overlay)   $4001        NES_CTRL: reset / pause
//   $2800-$2FFF  OSD attributes             $4020-$4027  SD disk registers
//   $3000-$31FF  SD sector buffer           $4030-$4034  cartridge loader
//   $8000-$FFFF  firmware ROM 32 KiB        $4038-$403B  cartridge configuration
//
// Bus timing: the CPU runs on every second clk (cpu_ce). A bus cycle is two clks:
// in the first the address is stable and the block RAMs read (registered read),
// in the second their data is on the bus and the CPU samples it at the end.
// Writes and every access with a side effect happen on that second clk only, so
// each CPU access acts exactly once.
//
// The NES is held in reset from power-on until the firmware clears NES_CTRL_RESET.
// The loader turns LD_DATA writes into the cartridge init port (fill_w / init_*).
module supervisor
    import zines_pkg::*;
#(
    parameter ROM_FILE = "",
    parameter integer CLK_FREQ_HZ = 50_000_000
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [7:0]  pad_buttons,    // A, B, Select, Start, Up, Down, Left, Right; 1 = pressed

    // NES control
    output logic        nes_reset,
    output logic        nes_pause,

    // cartridge init port
    output logic [2:0]  fill_w,
    output logic [14:0] init_addr,
    output logic [7:0]  init_data,

    // OSD text / attribute write port (osd_overlay)
    output logic        osd_text_we,
    output logic        osd_attr_we,
    output logic [10:0] osd_waddr,
    output logic [7:0]  osd_wdata,

    // SD card SPI
    output logic        sd_clk,
    output logic        sd_cmd,
    input  logic        sd_dat0,
    output logic        sd_cs_n,
    input  logic        sd_cd_n,

    output logic        undef           // simulation: undefined opcode
);

    // ------ CPU
    logic        cpu_ce;
    logic [15:0] cpu_addr;
    logic [7:0]  cpu_wdata;
    logic [7:0]  cpu_rdata;
    logic        cpu_rw;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cpu_ce <= 1'b0;
        else
            cpu_ce <= !cpu_ce;
    end

    mos6502 u_cpu (
        .clk(clk),
        .rst_n(rst_n),
        .ce(cpu_ce),
        .nmi_n(1'b1),
        .irq_n(1'b1),
        .data_in(cpu_rdata),
        .data_out(cpu_wdata),
        .addr(cpu_addr),
        .rw(cpu_rw),
        .undef(undef)
    );

    // ------ decode
    wire ram_sel     = cpu_addr[15:13] == OSD_ADDR_RAM[15:13];
    wire text_sel    = cpu_addr[15:11] == OSD_ADDR_TEXT[15:11];
    wire attr_sel    = cpu_addr[15:11] == OSD_ADDR_ATTR[15:11];
    wire sd_buf_sel  = cpu_addr[15:9]  == OSD_ADDR_SD_BUF[15:9];
    wire pad_sel     = cpu_addr        == OSD_ADDR_PAD1;
    wire pad_chg_sel = cpu_addr        == OSD_ADDR_PAD1_PRESSED;
    wire nes_ctl_sel = cpu_addr        == OSD_ADDR_NES_CTRL;
    wire sd_reg_sel  = cpu_addr[15:3]  == OSD_ADDR_SD_REGS[15:3];
    wire loader_sel  = cpu_addr[15:3]  == OSD_ADDR_LOADER[15:3];
    wire cart_sel    = cpu_addr[15:2]  == OSD_ADDR_CART[15:2];
    wire rom_sel     = cpu_addr[15]    == OSD_ADDR_ROM[15];

    wire rd_phase = cpu_rw && !cpu_ce;      // first clk of a read: block RAMs fetch
    wire wr       = !cpu_rw && cpu_ce;      // the one clk a write acts on
    wire rd       = cpu_rw && cpu_ce;       // the one clk a read with side effects acts on

    // ------ memories
    logic [7:0] ram_q, rom_q;

    sync_ram #(
        .ADDR_WIDTH(13)
    ) u_ram (
        .clk(clk),
        .we(ram_sel && wr),
        .re(ram_sel && rd_phase),
        .addr(cpu_addr[12:0]),
        .data_in(cpu_wdata),
        .data_out(ram_q)
    );

    sync_rom #(
        .ADDR_WIDTH(15),
        .ROM_FILE(ROM_FILE)
    ) u_rom (
        .clk(clk),
        .re(rom_sel && rd_phase),
        .addr(cpu_addr[14:0]),
        .data_out(rom_q)
    );

    assign osd_text_we = text_sel && wr;
    assign osd_attr_we = attr_sel && wr;
    assign osd_waddr   = cpu_addr[10:0];
    assign osd_wdata   = cpu_wdata;

    // ------ SD disk and its sector buffer (async read, as disk expects)
    logic [7:0] sd_reg_q;
    logic       sd_buf_active;
    logic [8:0] sd_buf_addr;
    logic       sd_buf_we;
    logic [7:0] sd_buf_wdata;
    logic [7:0] sd_buf [0:511];

    wire [8:0] sd_buf_a = sd_buf_active ? sd_buf_addr : cpu_addr[8:0];
    wire [7:0] sd_buf_q = sd_buf[sd_buf_a];

    always_ff @(posedge clk) begin
        if (sd_buf_active ? sd_buf_we : (sd_buf_sel && wr))
            sd_buf[sd_buf_a] <= sd_buf_active ? sd_buf_wdata : cpu_wdata;
    end

    disk #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_disk (
        .clk(clk),
        .rst_n(rst_n),
        .reg_sel(sd_reg_sel && cpu_ce),
        .reg_addr(cpu_addr[2:0]),
        .rw(cpu_rw),
        .data_in(cpu_wdata),
        .data_out(sd_reg_q),
        .buf_active(sd_buf_active),
        .buf_addr(sd_buf_addr),
        .buf_we(sd_buf_we),
        .buf_wdata(sd_buf_wdata),
        .buf_rdata(sd_buf_q),
        .sd_clk(sd_clk),
        .sd_cmd(sd_cmd),
        .sd_dat0(sd_dat0),
        .sd_cs_n(sd_cs_n),
        .sd_cd_n(sd_cd_n)
    );

    // ------ pad: PAD1_PRESSED is nonzero while the buttons differ from the last PAD1 read
    logic [7:0] pad_seen;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pad_seen <= 8'h00;
        else if (pad_sel && rd)
            pad_seen <= pad_buttons;
    end

    // ------ NES control, cartridge loader and configuration
    logic [7:0]  nes_ctrl;
    logic [7:0]  ld_sel;
    logic [23:0] ld_addr;
    logic [7:0]  cart_reg [0:3];

    assign nes_reset = nes_ctrl[0];
    assign nes_pause = nes_ctrl[1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nes_ctrl  <= NES_CTRL_RESET;
            ld_sel    <= LD_SEL_PRG_ROM;
            ld_addr   <= 24'd0;
            cart_reg  <= '{default: 8'h00};
            fill_w    <= FILL_NONE;
            init_addr <= 15'd0;
            init_data <= 8'h00;
        end else begin
            fill_w <= FILL_NONE;

            if (wr && nes_ctl_sel)
                nes_ctrl <= cpu_wdata & (NES_CTRL_RESET | NES_CTRL_PAUSE);

            if (wr && loader_sel) begin
                case (cpu_addr[2:0])
                    LD_REG_SEL:   ld_sel        <= cpu_wdata;
                    LD_REG_ADDR0: ld_addr[7:0]  <= cpu_wdata;
                    LD_REG_ADDR1: ld_addr[15:8] <= cpu_wdata;
                    LD_REG_ADDR2: ld_addr[23:16] <= cpu_wdata;
                    LD_REG_DATA: begin
                        case (ld_sel)
                            LD_SEL_PRG_ROM: fill_w <= FILL_PRG_DATA;
                            LD_SEL_CHR:     fill_w <= FILL_CHR_DATA;
                            default:        ;       // PRG RAM: not implemented yet
                        endcase
                        init_addr <= ld_addr[14:0];
                        init_data <= cpu_wdata;
                        ld_addr   <= ld_addr + 24'd1;
                    end
                    default: ;
                endcase
            end

            if (wr && cart_sel) begin
                cart_reg[cpu_addr[1:0]] <= cpu_wdata;
                init_data <= cpu_wdata;
                case (cpu_addr[1:0])
                    CART_REG_FLAGS:   fill_w <= FILL_VERTICAL;
                    CART_REG_PRG_16K: fill_w <= FILL_PRG_BANKS;
                    CART_REG_CHR_8K:  fill_w <= FILL_CHR_BANKS;
                    default:          ;
                endcase
            end
        end
    end

    // ------ read data
    always_comb begin
        if (ram_sel)
            cpu_rdata = ram_q;
        else if (rom_sel)
            cpu_rdata = rom_q;
        else if (sd_buf_sel)
            cpu_rdata = sd_buf_q;
        else if (sd_reg_sel)
            cpu_rdata = sd_reg_q;
        else if (pad_sel)
            cpu_rdata = pad_buttons;
        else if (pad_chg_sel)
            cpu_rdata = {7'd0, pad_seen != pad_buttons};
        else if (nes_ctl_sel)
            cpu_rdata = nes_ctrl;
        else if (loader_sel)
            case (cpu_addr[2:0])
                LD_REG_SEL:   cpu_rdata = ld_sel;
                LD_REG_ADDR0: cpu_rdata = ld_addr[7:0];
                LD_REG_ADDR1: cpu_rdata = ld_addr[15:8];
                LD_REG_ADDR2: cpu_rdata = ld_addr[23:16];
                default:      cpu_rdata = 8'h00;
            endcase
        else if (cart_sel)
            cpu_rdata = cart_reg[cpu_addr[1:0]];
        else
            cpu_rdata = 8'h00;
    end

    wire unused = &{1'b0, ld_addr[23:15]};

endmodule
