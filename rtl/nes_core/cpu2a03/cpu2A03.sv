// RP2A03 wrapper: 6502 core + OAM DMA ($4014) + APU.
// The addr/data_out/rw pins are the shared CPU bus: the core drives them
// normally, the DMA unit drives them while the core is halted.
module cpu2A03 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  logic        nmi_n,
    input  logic        irq_n,
    input  logic [7:0]  data_in,
    output logic [7:0]  data_out,
    output logic [15:0] addr,
    output logic        rw,
    output logic        out0,
    output logic        oe1_n,
    output logic        oe2_n,
    output logic [3:0]  audio1,
    output logic [3:0]  audio2,
    output logic [3:0]  audio3,
    output logic [3:0]  audio4,
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
    logic       apu_irq_n;

    logic [15:0] core_addr;
    logic [7:0]  core_data_out;
    logic [7:0]  core_data_in;
    logic        core_rw;

    logic [7:0]  apu_status;
    logic [7:0]  apu_data_in;

    localparam MEMIO_DMA            = 16'h4014;
    localparam MEMIO_APU_STATUS     = 16'h4015;
    localparam MEMIO_PAD1           = 16'h4016;
    localparam MEMIO_PAD2           = 16'h4017;

    wire dma_active             = (dma_state != DMA_IDLE);
    wire core_write_dma         = !core_rw && core_addr == MEMIO_DMA;
    wire core_write_pad1        = !core_rw && core_addr == MEMIO_PAD1;
    wire core_write_pad2        = !core_rw && core_addr == MEMIO_PAD2;
    
    wire core_read_apu_status   = core_rw && core_addr == MEMIO_APU_STATUS;
    wire core_read_pad1         = core_rw && core_addr == MEMIO_PAD1;
    wire core_read_pad2         = core_rw && core_addr == MEMIO_PAD2;
    
    wire core_ce = ce && !dma_active;

    // Output logic for out0 based on core writes to pad1, pad2
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out0    <= 1'b0;
        end else begin
            if (core_ce) begin
                if (core_write_pad1 || core_write_pad2)
                    out0 <= data_out[0];
            end
        end
    end

    // DMA state machine and control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_state <= DMA_IDLE;
            dma_page  <= 8'd0;
            dma_index <= 8'd0;
            dma_data  <= 8'd0;
            odd_cycle <= 1'b0;
        end else if (ce) begin
            odd_cycle <= !odd_cycle;

            case (dma_state)
                DMA_IDLE: begin
                    if (core_ce && core_write_dma) begin
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
        .clk(clk),
        .rst_n(rst_n),
        .ce(core_ce),
        .nmi_n(nmi_n),
        .irq_n(irq_n && apu_irq_n),     // IRQ line is wired-AND with the APU
        .data_in(core_data_in),
        .data_out(core_data_out),
        .addr(core_addr),
        .rw(core_rw),
        .undef(undef)
    );

    apu2A03 u_apu (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .addr(core_addr),
        .data_in(apu_data_in),
        .rw(core_rw),
        .data_out(apu_status),
        .irq_n(apu_irq_n),
        .audio1(audio1),
        .audio2(audio2),
        .audio3(audio3),
        .audio4(audio4)
    );

    // Bus ownership. While DMA owns the bus (core_ce = 0)
    // the bus is parked on a harmless cartridge read.
    // Every output gets a default first so the block stays purely combinational
    // (no latches); internal register accesses also appear on the external bus,
    // as on the real 2A03.
    always_comb begin
        core_data_in = data_in;
        apu_data_in  = core_data_out;
        addr         = core_addr;
        data_out     = core_data_out;
        rw           = core_rw;
        oe1_n        = 1'b1;
        oe2_n        = 1'b1;

        if (!dma_active) begin
            if (core_read_pad1)
                oe1_n = 1'b0;
            else if (core_read_pad2)
                oe2_n = 1'b0;
            else if (core_read_apu_status)
                core_data_in = apu_status;
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
