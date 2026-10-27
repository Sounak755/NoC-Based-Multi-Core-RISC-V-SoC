`timescale 1ns/1ps

module rv32i_regfile (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [4:0]  read_addr1,
    input  logic [4:0]  read_addr2,
    output logic [31:0] read_data1,
    output logic [31:0] read_data2,

    input  logic        write_enable,
    input  logic [4:0]  write_addr,
    input  logic [31:0] write_data
);

    logic [31:0] registers [1:31];
    integer i;

    // x0 is hardwired to zero; x1-x31 are writable.
    always_comb begin
        if (read_addr1 == 5'd0)
            read_data1 = 32'b0;
        else
            read_data1 = registers[read_addr1];

        if (read_addr2 == 5'd0)
            read_data2 = 32'b0;
        else
            read_data2 = registers[read_addr2];
    end

    // Synchronous register writes and active-low reset.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end
        else if (write_enable && (write_addr != 5'd0)) begin
            registers[write_addr] <= write_data;
        end
    end

endmodule