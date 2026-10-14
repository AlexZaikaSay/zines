
`include "boards/rp_devboard.sv"

`timescale 1ns/1ps

module tb_300_audio (
    input logic clk
);
    parameter MEM_FILE = "./tests/304_apu_noise.tv";
    
    logic       rst_n;

    logic [3:0] audio1;
    logic [3:0] audio2;
    logic [3:0] audio3;
    logic [3:0] audio4;


    rp_devboard #(
        .MEM_FILE(MEM_FILE)
    )
    db_device
    (
        .clk(clk),
        .rst_n(rst_n),
        .audio1(audio1),
        .audio2(audio2),
        .audio3(audio3),
        .audio4(audio4)
    );

    import "DPI-C" function void sdl_audio_init();
    import "DPI-C" function void sdl_audio_sample(input int audio1, input int audio2, input int audio3, input int audio4);
    import "DPI-C" function void sdl_audio_close();

    initial sdl_audio_init();

    // One sample per CPU clock; the SDL side resamples and mixes the pulse channels.
    always @(posedge clk) begin
        if (rst_n === 1'b1) begin
            sdl_audio_sample((^audio1 === 1'bx) ? 0 : int'(audio1),
                             (^audio2 === 1'bx) ? 0 : int'(audio2),
                             (^audio3 === 1'bx) ? 0 : int'(audio3),
                             (^audio4 === 1'bx) ? 0 : int'(audio4));
        end
    end

    initial begin
        rst_cnt = 2'd0;
        cyc = 0;
        // $dumpfile("tb_300_audio.vcd");
        // $dumpvars(0, tb_300_audio);
    end

    // clk is driven by utils/sim_main.cpp; reset is held for 2 clocks, 
    // run ends after 6000000 CPU cycles.
    logic [1:0] rst_cnt;
    integer     cyc;
    always @(posedge clk) begin
        if (rst_cnt != 2'd2) 
            rst_cnt <= rst_cnt + 2'd1;
        cyc <= cyc + 1;
        if (cyc == 6000000) begin
            sdl_audio_close();
            $finish;
        end
    end
    
    assign rst_n = (rst_cnt == 2'd2);


endmodule
