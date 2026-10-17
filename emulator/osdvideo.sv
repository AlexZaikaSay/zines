`include "nes.sv"
`include "cartridge/cartridge_sim.sv"
`include "joystick/joystick_sim.sv"

`timescale 1ns/1ps

module osdvideo (
    input logic clk
);
 

    initial begin
        // $dumpfile("osdvideo.vcd");
        // $dumpvars(0, osdvideo);
    end

    logic [1:0] rst_cnt;
    integer     cyc;
    always @(posedge clk) begin
        if (rst_cnt != 2'd2) 
            rst_cnt <= rst_cnt + 2'd1;
        cyc <= cyc + 1;
        if (cyc == 60000) begin
            $finish;
        end
    end


    always @(posedge clk) begin
        // if (cpu_undef === 1'b1)
        //     $fatal(1, "osdvideo: undefined opcode at %04h", cpu_addr);
    end

endmodule
