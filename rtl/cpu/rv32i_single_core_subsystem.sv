
`timescale 1ns/1ps

module rv32i_single_core_subsystem #(
    parameter integer IMEM_DEPTH_WORDS = 64,
    parameter integer DMEM_DEPTH_WORDS = 256
) (
    input  logic        clk,
    input  logic        rst_n,

    // Instruction fetch interface
    output logic [31:0] instruction_address,
    output logic [31:0] instruction_data,

    // Data memory interface
    output logic        data_memory_read_enable,
    output logic        data_memory_write_enable,
    output logic [2:0]  data_memory_funct3,
    output logic [31:0] data_memory_address,
    output logic [31:0] data_memory_write_data,
    input  logic [31:0] data_memory_read_data,

    // Instruction retirement interface
    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [31:0] retire_instruction,
    output logic        retire_rd_we,
    output logic [4:0]  retire_rd,
    output logic [31:0] retire_rd_data
);

    // ------------------------------------------------------------
    // Instruction memory
    // ------------------------------------------------------------
    rv32i_instruction_memory #(
        .DEPTH_WORDS(IMEM_DEPTH_WORDS)
    ) instruction_mem (
        .address(instruction_address),
        .instruction(instruction_data)
    );

    // ------------------------------------------------------------
    // RV32I CPU core
    // ------------------------------------------------------------
    rv32i_core cpu (
        .clk(clk),
        .rst_n(rst_n),

        .instruction_address(instruction_address),
        .instruction_data(instruction_data),

        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_instruction(retire_instruction),
        .retire_rd_we(retire_rd_we),
        .retire_rd(retire_rd),
        .retire_rd_data(retire_rd_data),

        .data_memory_read_enable(data_memory_read_enable),
        .data_memory_write_enable(data_memory_write_enable),
        .data_memory_funct3(data_memory_funct3),
        .data_memory_address(data_memory_address),
        .data_memory_write_data(data_memory_write_data),
        .data_memory_read_data(data_memory_read_data)
    );

    // ------------------------------------------------------------
    // Data memory
    // ------------------------------------------------------------
    rv32i_data_memory #(
        .DEPTH_WORDS(DMEM_DEPTH_WORDS)
    ) data_mem (
        .clk(clk),
        .rst_n(rst_n),

        .mem_read(data_memory_read_enable),
        .mem_write(data_memory_write_enable),
        .funct3(data_memory_funct3),
        .address(data_memory_address),
        .write_data(data_memory_write_data),
        .read_data(data_memory_read_data)
    );

endmodule
