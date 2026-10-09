
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_070_nmi;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/070_nmi.tv";
    logic clk;
    logic rst_n;
    logic nmi_n;

    devboard #(
        .MEM_FILE(MEM_FILE)
    )
    db_device
    (
        .clk(clk),
        .rst_n(rst_n),
        .nmi_n(nmi_n)
    );

    initial begin
        $dumpfile("tb_070_nmi.vcd");
        $dumpvars(0, tb_070_nmi);
        nmi_n = 1;
        #1 rst_n = 0; #2; rst_n = 1;
        #(31 + RESET_CYCLES * CYCLE_LEN); nmi_n = 0; #1; nmi_n = 1;  // 2 clk earlier: nmi is synchronized in the CPU
        #200; nmi_n = 0; #1; nmi_n = 1;
        #160; nmi_n = 0; #1; nmi_n = 1;
    end

    initial begin
        for (integer i = 0; i < 60 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                13: begin
                    // first int
                    if (db_device.cpu.pc_l !== 8'h0d  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'he4)
                        $error("TEST FAILED: NMI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                21: begin
                    // first rti
                    if (db_device.cpu.pc_l !== 8'h04  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'he0)
                        $error("TEST FAILED: RTI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                32: begin
                    // second int
                    if (db_device.cpu.pc_l !== 8'h0d  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'he4)
                        $error("TEST FAILED: NMI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                40: begin
                    // second rti
                    if (db_device.cpu.pc_l !== 8'h06  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'he0)
                        $error("TEST FAILED: RTI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                49: begin
                    // third int
                    if (db_device.cpu.pc_l !== 8'h0d  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'he4)
                        $error("TEST FAILED: NMI, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
                end
                57: begin
                    // third rti
                    if (db_device.cpu.pc_l !== 8'h07  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'he0)
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
