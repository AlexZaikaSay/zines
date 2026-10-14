
`include "cpu/mem.sv"
`include "cpu/cpu2A03.sv"
`include "joystick_sim.sv"

module rp_devboard 
#(
    parameter MEM_FILE = ""
)
(
    input logic         clk,
    input logic         rst_n,
    input logic         nmi_n = 1'b1,
    input logic         irq_n = 1'b1,
    input logic [7:0]   joy1_buttons = 8'h00,   // A, B, Select, Start, Up, Down, Left, Right
    input logic [7:0]   joy2_buttons = 8'h00,
    output logic [3:0]  audio1,
    output logic [3:0]  audio2,
    output logic [3:0]  audio3,
    output logic [3:0]  audio4
);

    logic [15:0] addr;
    logic [7:0] cpu_data;
    logic [7:0] mem_data;
    logic rw;
    logic [7:0] bus_data;
    logic joy_strob;
    logic joy1_oe_n;
    logic joy2_oe_n;
    logic [7:0] joy1_data;
    logic [7:0] joy2_data;
    logic undef;

    cpu2A03 cpu (
        .clk,
        .rst_n,
        .addr,
        .data_out(cpu_data),
        .data_in(bus_data),
        .rw(rw),
        .nmi_n,
        .irq_n,
        .out0(joy_strob),
        .oe1_n(joy1_oe_n),
        .oe2_n(joy2_oe_n),
        .audio1(audio1),
        .audio2(audio2),
        .audio3(audio3),
        .audio4(audio4),
        .undef
    );

    // Controllers on $4016/$4017
    joystick_sim u_joy1 (
        .strob(joy_strob),
        .oe_n(joy1_oe_n),
        .buttons(joy1_buttons),
        .data(joy1_data)
    );

    joystick_sim u_joy2 (
        .strob(joy_strob),
        .oe_n(joy2_oe_n),
        .buttons(joy2_buttons),
        .data(joy2_data)
    );

    always_comb begin
        if (!joy1_oe_n)
            bus_data = joy1_data;
        else if (!joy2_oe_n)
            bus_data = joy2_data;
        else
            bus_data = mem_data;
    end

    // undef is probed hierarchically by the testbenches that care about it
    // (tests may run past their program into undefined opcodes on purpose)
    wire unused = &{1'b0, undef};

    mem #(
        .ADDR_WIDTH(16),
        .MEM_FILE(MEM_FILE)
    ) memory (
        .clk,
        .addr,
        .data_out(mem_data),
        .data_in(cpu_data),
        .rw
    );

endmodule
