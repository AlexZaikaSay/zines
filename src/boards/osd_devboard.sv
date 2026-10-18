
`include "cpu/mos6502.sv"
`include "cpu/mem.sv"
`include "cpu/rom.sv"
`include "ppu/ppu_sim.sv"

module osd_devboard 
#(
    parameter ROM_FILE = ""
)
(
    input logic clk,
    input logic rst_n,
    output logic [8:0] scanline,
    output logic [8:0] cycle,
    output logic [7:0] pixel_palette
);

    logic [15:0] addr;
    logic [7:0] cpu_data;
    logic [7:0] mem_data;
    logic [7:0] ram_data;
    logic [7:0] rom_data;
    logic rw;
    logic undef;

    wire ram_selected           = addr[15:13] == 3'b000;    // $0000-$1FFF
    wire osd_register_selected  = addr[15:13] == 3'b001;    // $2000-$3FFF
    wire rom_selected           = addr[15];                 // $8000-$FFFF

    mos6502 cpu (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .data_out(cpu_data),
        .data_in(mem_data),
        .rw(rw),
        .nmi_n(1),
        .irq_n(1),
        .undef(undef)
    );

    assign mem_data = ram_selected ? ram_data :
                      rom_selected ? rom_data :
                      8'h00;

    ppu_sim ppu (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_color(pixel_palette),
        .scanline(scanline),
        .cycle(cycle)
    );

    localparam MEMIO_PRINT_CHAR = 13'h2000;

    wire print_char_w = osd_register_selected && (addr[12:0] == MEMIO_PRINT_CHAR) && !rw;

    always_ff @(posedge clk) begin
        if (print_char_w) begin
            $display("%c", cpu_data);
        end
    end

    // Async read: mos6502 samples data in the same cycle it drives addr
    mem #(
        .ADDR_WIDTH(13)
    ) ram (
        .clk(clk),
        .addr(addr[12:0]),
        .data_in(cpu_data),
        .rw(rw),
        .cs_n(!ram_selected),
        .oe_n(!rw),
        .data_out(ram_data)
    );

    rom #(
        .ADDR_WIDTH(15),
        .ROM_FILE(ROM_FILE)
    ) rom (
        .addr(addr),
        .data_out(rom_data),
        .re(rom_selected && rw)
    );

endmodule
