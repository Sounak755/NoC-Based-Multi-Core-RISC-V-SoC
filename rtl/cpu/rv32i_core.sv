
`timescale 1ns/1ps

module rv32i_core #(
    parameter bit USE_MEMORY_HANDSHAKE = 1'b0
) (
    input  logic        clk,
    input  logic        rst_n,

    output logic [31:0] instruction_address,
    input  logic [31:0] instruction_data,

    output logic        data_memory_read_enable,
    output logic        data_memory_write_enable,
    output logic [2:0]  data_memory_funct3,
    output logic [31:0] data_memory_address,
    output logic [31:0] data_memory_write_data,
    input  logic [31:0] data_memory_read_data,

    input  logic        data_memory_request_ready,
    input  logic        data_memory_response_valid,
    output logic        data_memory_response_ready,

    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [31:0] retire_instruction,
    output logic        retire_rd_we,
    output logic [4:0]  retire_rd,
    output logic [31:0] retire_rd_data
);

    logic [31:0] pc;
    logic [31:0] next_pc;
    logic [31:0] pc_plus_4;

    logic [31:0] rs1_data, rs2_data;
    logic [31:0] immediate;
    logic [31:0] alu_result;
    logic alu_zero;

    logic [3:0] alu_control;
    logic [2:0] immediate_type;

    logic reg_write, alu_src;
    logic mem_read, mem_write, mem_to_reg;
    logic branch, jump, jalr, illegal_instruction;

    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    logic [2:0] funct3;

    logic branch_taken;
    logic effective_reg_write;
    logic [31:0] writeback_data;

    logic is_memory_instruction;
    logic memory_request_fire;
    logic memory_response_fire;
    logic memory_pending;
    logic instruction_complete;

    assign instruction_address = pc;
    assign pc_plus_4 = pc + 32'd4;

    assign rs1_addr = instruction_data[19:15];
    assign rs2_addr = instruction_data[24:20];
    assign rd_addr  = instruction_data[11:7];
    assign funct3   = instruction_data[14:12];

    rv32i_decoder decoder (
        .instruction(instruction_data),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .illegal_instruction(illegal_instruction),
        .alu_control(alu_control),
        .immediate_type(immediate_type)
    );

    rv32i_imm_gen imm_gen (
        .instruction(instruction_data),
        .immediate_type(immediate_type),
        .immediate(immediate)
    );

    rv32i_regfile register_file (
        .clk(clk),
        .rst_n(rst_n),
        .read_addr1(rs1_addr),
        .read_addr2(rs2_addr),
        .read_data1(rs1_data),
        .read_data2(rs2_data),
        .write_enable(effective_reg_write),
        .write_addr(rd_addr),
        .write_data(writeback_data)
    );

    rv32i_alu alu (
        .operand_a(rs1_data),
        .operand_b(alu_src ? immediate : rs2_data),
        .alu_control(alu_control),
        .result(alu_result),
        .zero(alu_zero)
    );

    always @(*) begin
        case (funct3)
            3'b000: branch_taken = (rs1_data == rs2_data);
            3'b001: branch_taken = (rs1_data != rs2_data);
            3'b100: branch_taken =
                ($signed(rs1_data) < $signed(rs2_data));
            3'b101: branch_taken =
                ($signed(rs1_data) >= $signed(rs2_data));
            3'b110: branch_taken = (rs1_data < rs2_data);
            3'b111: branch_taken = (rs1_data >= rs2_data);
            default: branch_taken = 1'b0;
        endcase
    end

    always @(*) begin
        next_pc = pc_plus_4;

        if (!illegal_instruction) begin
            if (branch && branch_taken)
                next_pc = pc + immediate;
            else if (jump && jalr)
                next_pc = (rs1_data + immediate) & 32'hFFFF_FFFE;
            else if (jump)
                next_pc = pc + immediate;
        end
    end

    assign is_memory_instruction =
        (mem_read || mem_write) && !illegal_instruction;

    assign data_memory_read_enable =
        rst_n && mem_read && !illegal_instruction &&
        ((!USE_MEMORY_HANDSHAKE) || !memory_pending);

    assign data_memory_write_enable =
        rst_n && mem_write && !illegal_instruction &&
        ((!USE_MEMORY_HANDSHAKE) || !memory_pending);

    assign data_memory_address    = alu_result;
    assign data_memory_write_data = rs2_data;
    assign data_memory_funct3     = funct3;

    assign memory_request_fire =
        USE_MEMORY_HANDSHAKE &&
        is_memory_instruction &&
        !memory_pending &&
        data_memory_request_ready &&
        rst_n;

    assign memory_response_fire =
        USE_MEMORY_HANDSHAKE &&
        memory_pending &&
        data_memory_response_valid &&
        rst_n;

    assign data_memory_response_ready =
        USE_MEMORY_HANDSHAKE &&
        memory_pending &&
        rst_n;

    assign instruction_complete =
        !USE_MEMORY_HANDSHAKE
        ? 1'b1
        : (is_memory_instruction
            ? memory_response_fire
            : !memory_pending);

    always @(posedge clk) begin
        if (!rst_n) begin
            pc             <= 32'b0;
            memory_pending <= 1'b0;
        end else begin
            if (instruction_complete)
                pc <= next_pc;

            if (USE_MEMORY_HANDSHAKE) begin
                if (memory_request_fire)
                    memory_pending <= 1'b1;

                if (memory_response_fire)
                    memory_pending <= 1'b0;
            end else begin
                memory_pending <= 1'b0;
            end
        end
    end

    always @(*) begin
        case (instruction_data[6:0])
            7'b1101111,
            7'b1100111:
                writeback_data = pc_plus_4;

            7'b0110111:
                writeback_data = immediate;

            7'b0010111:
                writeback_data = pc + immediate;

            default: begin
                if (mem_to_reg)
                    writeback_data = data_memory_read_data;
                else
                    writeback_data = alu_result;
            end
        endcase
    end

    assign effective_reg_write =
        reg_write &&
        !illegal_instruction &&
        ((!USE_MEMORY_HANDSHAKE) ||
         !is_memory_instruction ||
         memory_response_fire);

    assign retire_valid =
        rst_n &&
        !illegal_instruction &&
        ((!USE_MEMORY_HANDSHAKE) ||
         !is_memory_instruction ||
         memory_response_fire);

    assign retire_pc          = pc;
    assign retire_instruction = instruction_data;
    assign retire_rd_we       = effective_reg_write;
    assign retire_rd          = rd_addr;
    assign retire_rd_data     = writeback_data;

endmodule
