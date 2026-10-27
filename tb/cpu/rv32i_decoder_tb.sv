`timescale 1ns/1ps

module rv32i_decoder_tb;

    logic [31:0] instruction;

    logic reg_write;
    logic alu_src;
    logic mem_read;
    logic mem_write;
    logic mem_to_reg;
    logic branch;
    logic jump;
    logic jalr;
    logic illegal_instruction;
    logic [3:0] alu_control;
    logic [2:0] immediate_type;

    integer tests_passed;

    localparam [3:0] ALU_ADD  = 4'b0000;
    localparam [3:0] ALU_SUB  = 4'b0001;
    localparam [2:0] IMM_I = 3'd0;
    localparam [2:0] IMM_S = 3'd1;
    localparam [2:0] IMM_B = 3'd2;
    localparam [2:0] IMM_U = 3'd3;
    localparam [2:0] IMM_J = 3'd4;

    rv32i_decoder dut (
        .instruction(instruction),
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

    task check_instruction;
        input [31:0] instr;
        input exp_reg_write;
        input exp_alu_src;
        input exp_mem_read;
        input exp_mem_write;
        input exp_mem_to_reg;
        input exp_branch;
        input exp_jump;
        input exp_jalr;
        input exp_illegal;
        input [3:0] exp_alu;
        input [2:0] exp_imm;
        input [255:0] test_name;

        begin
            instruction = instr;
            #1;

            if (reg_write !== exp_reg_write ||
                alu_src !== exp_alu_src ||
                mem_read !== exp_mem_read ||
                mem_write !== exp_mem_write ||
                mem_to_reg !== exp_mem_to_reg ||
                branch !== exp_branch ||
                jump !== exp_jump ||
                jalr !== exp_jalr ||
                illegal_instruction !== exp_illegal) begin

                $display("FAIL: %0s - control signals", test_name);
                $display("Instruction: %h", instr);
                $display("Actual controls: regwrite=%b alusrc=%b memread=%b memwrite=%b memtoreg=%b branch=%b jump=%b jalr=%b illegal=%b",
                    reg_write, alu_src, mem_read, mem_write,
                    mem_to_reg, branch, jump, jalr, illegal_instruction);
                $fatal(1, "Decoder control mismatch");
            end

            if (alu_control !== exp_alu) begin
                $display("FAIL: %0s - ALU control", test_name);
                $fatal(1, "Expected %b, got %b", exp_alu, alu_control);
            end

            if (immediate_type !== exp_imm) begin
                $display("FAIL: %0s - immediate type", test_name);
                $fatal(1, "Expected %b, got %b", exp_imm, immediate_type);
            end

            tests_passed = tests_passed + 1;
            $display("PASS: %0s", test_name);
        end
    endtask

    initial begin
        instruction = 32'b0;
        tests_passed = 0;

        $display("Starting RV32I decoder tests");

        // ADD x3, x1, x2
        check_instruction(
            32'h002081B3,
            1, 0, 0, 0, 0, 0, 0, 0, 0,
            ALU_ADD, IMM_I, "ADD"
        );

        // SUB x3, x1, x2
        check_instruction(
            32'h402081B3,
            1, 0, 0, 0, 0, 0, 0, 0, 0,
            ALU_SUB, IMM_I, "SUB"
        );

        // ADDI x1, x0, 5
        check_instruction(
            32'h00500093,
            1, 1, 0, 0, 0, 0, 0, 0, 0,
            ALU_ADD, IMM_I, "ADDI"
        );

        // LW x2, 0(x1)
        check_instruction(
            32'h0000A103,
            1, 1, 1, 0, 1, 0, 0, 0, 0,
            ALU_ADD, IMM_I, "LW"
        );

        // SW x2, 4(x1)
        check_instruction(
            32'h0020A223,
            0, 1, 0, 1, 0, 0, 0, 0, 0,
            ALU_ADD, IMM_S, "SW"
        );

        // BEQ x1, x2, +8
        check_instruction(
            32'h00208463,
            0, 0, 0, 0, 0, 1, 0, 0, 0,
            ALU_SUB, IMM_B, "BEQ"
        );

        // JAL x1, +8
        check_instruction(
            32'h008000EF,
            1, 0, 0, 0, 0, 0, 1, 0, 0,
            ALU_ADD, IMM_J, "JAL"
        );

        // JALR x1, 0(x2)
        check_instruction(
            32'h000100E7,
            1, 1, 0, 0, 0, 0, 1, 1, 0,
            ALU_ADD, IMM_I, "JALR"
        );

        // LUI x1, 0x12345
        check_instruction(
            32'h123450B7,
            1, 1, 0, 0, 0, 0, 0, 0, 0,
            ALU_ADD, IMM_U, "LUI"
        );

        // AUIPC x1, 0x12345
        check_instruction(
            32'h12345097,
            1, 1, 0, 0, 0, 0, 0, 0, 0,
            ALU_ADD, IMM_U, "AUIPC"
        );

        // Unsupported opcode
        check_instruction(
            32'h00000000,
            0, 0, 0, 0, 0, 0, 0, 0, 1,
            ALU_ADD, IMM_I, "Illegal opcode"
        );

        // Invalid R-type funct7 encoding
        check_instruction(
            32'h202081B3,
            0, 0, 0, 0, 0, 0, 0, 0, 1,
            ALU_ADD, IMM_I, "Illegal R-type encoding"
        );

        $display("");
        $display("ALL DECODER TESTS PASSED: %0d tests", tests_passed);
        $finish;
    end

endmodule