`include "cpu/mos6502.sv"

// RP2A03 wrapper: 6502 core + OAM DMA ($4014). APU is not implemented.
// The addr/data_out/rw pins are the shared CPU bus: the core drives them
// normally, the DMA unit drives them while the core is halted.
module cpu2A03 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        nmi_n,
    input  logic        irq_n,
    input  logic [7:0]  data_in,
    output logic [7:0]  data_out,
    output logic [15:0] addr,
    output logic        rw,
    output logic        m2,
    output logic        undef
);
    localparam logic [2:0] DMA_IDLE  = 3'd0;
    localparam logic [2:0] DMA_HALT  = 3'd1;
    localparam logic [2:0] DMA_ALIGN = 3'd2;
    localparam logic [2:0] DMA_READ  = 3'd3;
    localparam logic [2:0] DMA_WRITE = 3'd4;

    logic [2:0] dma_state;
    logic [7:0] dma_page;
    logic [7:0] dma_index;
    logic [7:0] dma_data;
    logic       odd_cycle;
    logic       core_enabled;

    logic [15:0] core_addr;
    logic [7:0]  core_data_out;
    logic        core_rw;

    wire core_clk = clk && core_enabled;
    wire dma_active = (dma_state != DMA_IDLE);
    wire core_write_dma = !core_rw && core_addr == 16'h4014;

    // Core clock gate: enable changes only while clk is low
    always_ff @(negedge clk or negedge rst_n) begin
        if (!rst_n)
            core_enabled <= 1'b1;
        else
            core_enabled <= !dma_active;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_state <= DMA_IDLE;
            dma_page  <= 8'd0;
            dma_index <= 8'd0;
            dma_data  <= 8'd0;
            odd_cycle <= 1'b0;
        end else begin
            odd_cycle <= !odd_cycle;

            case (dma_state)
                DMA_IDLE: begin
                    if (core_enabled && core_write_dma) begin
                        dma_page  <= core_data_out;
                        dma_index <= 8'd0;
                        dma_state <= DMA_HALT;
                    end
                end
                DMA_HALT:  dma_state <= odd_cycle ? DMA_ALIGN : DMA_READ;
                DMA_ALIGN: dma_state <= DMA_READ;
                DMA_READ: begin
                    dma_data  <= data_in;
                    dma_state <= DMA_WRITE;
                end
                DMA_WRITE: begin
                    dma_index <= dma_index + 8'd1;
                    dma_state <= (dma_index == 8'hFF) ? DMA_IDLE : DMA_READ;
                end
                default: dma_state <= DMA_IDLE;
            endcase
        end
    end

    mos6502 u_core (
        .clk(core_clk),
        .rst_n(rst_n),
        .nmi_n(nmi_n),
        .irq_n(irq_n),
        .data_in(data_in),
        .data_out(core_data_out),
        .addr(core_addr),
        .rw(core_rw),
        .m2(m2),
        .undef(undef)
    );

    // Bus ownership. While the core is gated off (including the cycle after
    // DMA ends) the bus is parked on a harmless cartridge read.
    always_comb begin
        if (core_enabled && !dma_active) begin
            addr     = core_addr;
            data_out = core_data_out;
            rw       = core_rw;
        end else begin
            case (dma_state)
                DMA_READ: begin
                    addr     = {dma_page, dma_index};
                    data_out = 8'h00;
                    rw       = 1'b1;
                end
                DMA_WRITE: begin
                    addr     = 16'h2004;
                    data_out = dma_data;
                    rw       = 1'b0;
                end
                default: begin
                    addr     = 16'hFFFF;
                    data_out = 8'h00;
                    rw       = 1'b1;
                end
            endcase
        end
    end

endmodule
