`timescale 1ns/1ps

module rv32i_pc (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] next_pc,
    output logic [31:0] pc
);

    always_ff @(posedge clk) begin
        if (!rst_n)
            pc <= 32'b0;
        else
            pc <= next_pc;
    end

endmodule