
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_072_irq_nmi;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/072_irq_nmi.tv";
    logic clk;
    logic rst;
    logic nmi;
    logic irq;

    devboard #(
        .MEM_FILE(MEM_FILE),
        .PC_START(16'h0400)
    )
    db_device
    (
        .clk(clk),
        .rst(rst),
        .nmi(nmi),
        .irq(irq)
    );

    initial begin
        $dumpfile("tb_072_irq_nmi.vcd");
        $dumpvars(0, tb_072_irq_nmi);
        nmi = 1;
        irq = 1;
        #1 rst = 0; #2; rst = 1;
        #51; irq = 0; #18; irq = 1;
        #150; nmi = 0; #1; nmi = 1;  // 2 clk earlier: nmi is synchronized in the CPU
        #160; nmi = 0; #1; nmi = 1;
        #50; irq = 0; #127; irq = 1;
        #1; nmi = 0; #1; nmi = 1;
    end

    initial begin
        for (integer i = 0; i < 100; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                13: begin
                    // first irq
                    if (db_device.cpu.pc_l !== 8'h0d  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha4)
                        $error("TEST FAILED: IRQ, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                21: begin
                    // first irq rti
                    if (db_device.cpu.pc_l !== 8'h04  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha0)
                        $error("TEST FAILED: RTI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                32: begin
                    // first nmi
                    if (db_device.cpu.pc_l !== 8'h0f  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha4)
                        $error("TEST FAILED: NMI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                42: begin
                    // first nmi rti
                    if (db_device.cpu.pc_l !== 8'h06  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha0)
                        $error("TEST FAILED: RTI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                47: begin
                    // second nmi
                    if (db_device.cpu.pc_l !== 8'h0f  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha4)
                        $error("TEST FAILED: NMI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                57: begin
                    // second nmi rti
                    if (db_device.cpu.pc_l !== 8'h06  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha0)
                        $error("TEST FAILED: RTI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                64: begin
                    // second irq
                    if (db_device.cpu.pc_l !== 8'h0d  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha4)
                        $error("TEST FAILED: IRQ, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                69: begin
                    // third nmi
                    if (db_device.cpu.pc_l !== 8'h0f  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha4)
                        $error("TEST FAILED: NMI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                77: begin
                    // third nmi rti
                    if (db_device.cpu.pc_l !== 8'h0d  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha4)
                        $error("TEST FAILED: RTI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                85: begin
                    // second irq rti
                    if (db_device.cpu.pc_l !== 8'h06  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'ha0)
                        $error("TEST FAILED: RTI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                default: begin
                    // No specific check for this cycle
                end
            endcase
        end
    end

    always @(negedge clk)
    begin
        // Check for specific memory write conditions here
    end
  
endmodule

/* verilator lint_on STMTDLY */
