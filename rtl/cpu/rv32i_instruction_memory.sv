`timescale 1ns/1ps

module rv32i_instruction_memory #(
    parameter integer DEPTH_WORDS = 64
) (
    input  logic [31:0] address,
    output logic [31:0] instruction
);

    logic [31:0] memory [0:DEPTH_WORDS-1];
    integer i;

    localparam logic [31:0] NOP = 32'h00000013;

    initial begin
        // Initialize unused locations to NOP.
        for (i = 0; i < DEPTH_WORDS; i = i + 1)
            memory[i] = NOP;

        // Demonstration program.
        memory[0] = 32'h00500093; // ADDI x1, x0, 5
        memory[1] = 32'h00A00113; // ADDI x2, x0, 10
        memory[2] = 32'h002081B3; // ADD  x3, x1, x2
        memory[3] = 32'h00000013; // NOP
    end

    always_comb begin
        if ((address[1:0] != 2'b00) ||
            (address[31:2] >= DEPTH_WORDS))
            instruction = NOP;
        else
            instruction = memory[address[31:2]];
    end

endmodule