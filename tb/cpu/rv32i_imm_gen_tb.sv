`timescale 1ns/1ps

module rv32i_imm_gen_tb;

logic [31:0] instruction;
    logic [2:0] immediate_type;
    logic [31:0] immediate;

    integer tests_passed;

localparam [2:0] IMM_I = 3'd0;
    localparam [2:0] IMM_S = 3'd1;
    localparam [2:0] IMM_B = 3'd2;
    localparam [2:0] IMM_U = 3'd3;
    localparam [2:0] IMM_J = 3'd4;

rv32i_imm_gen dut (
        .instruction(instruction),
        .immediate_type(immediate_type),
        .immediate(immediate)
    );

task check_immediate;
        input [31:0] instr;
        input [2:0] imm_type;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            instruction = instr;
            immediate_type = imm_type;
            #1;

if (immediate !== expected) begin
                $display("FAIL: %0s", test_name);
                $display("Instruction: %h", instr);
                $display("Expected:    %h", expected);
                $display("Actual:      %h", immediate);
                $fatal(1, "Immediate generator mismatch");
            end

tests_passed = tests_passed + 1;
            $display("PASS: %0s -> %h", test_name, immediate);
        end
    endtask

initial begin
        instruction = 32'b0;
        immediate_type = IMM_I;
        tests_passed = 0;

        $display("Starting RV32I immediate generator tests");

// I-type: positive 5.
        check_immediate(
            32'h00500093, IMM_I, 32'd5,
            "I-type positive"
        );

// I-type: -1.
        check_immediate(
            32'hFFF00093, IMM_I, 32'hFFFF_FFFF,
            "I-type negative"
        );

// I-type: minimum signed 12-bit immediate (-2048).
        check_immediate(
            32'h80000093, IMM_I, 32'hFFFF_F800,
            "I-type minimum negative"
        );

// S-type: SW with offset +4.
        check_immediate(
            32'h0020A223, IMM_S, 32'd4,
            "S-type positive"
        );

// S-type: immediate -1, encoded as all 12 bits set.
        check_immediate(
            32'hFE20AFA3, IMM_S, 32'hFFFF_FFFF,
            "S-type negative"
        );

// B-type: BEQ with offset +8.
        check_immediate(
            32'h00208463, IMM_B, 32'd8,
            "B-type positive"
        );

// B-type: branch offset -4.
        check_immediate(
            32'hFE208EE3, IMM_B, 32'hFFFF_FFFC,
            "B-type negative"
        );

// U-type: upper immediate 0x12345.
        check_immediate(
            32'h123450B7, IMM_U, 32'h12345000,
            "U-type positive"
        );

// U-type: top bit set.
        check_immediate(
            32'h800000B7, IMM_U, 32'h80000000,
            "U-type high bit"
        );

// J-type: JAL offset +8.
        check_immediate(
            32'h008000EF, IMM_J, 32'd8,
            "J-type positive"
        );

// J-type: JAL offset -4.
        check_immediate(
            32'hFFDFF0EF, IMM_J, 32'hFFFF_FFFC,
            "J-type negative"
        );

// Unsupported immediate type returns zero.
        check_immediate(
            32'hFFFFFFFF, 3'd7, 32'b0,
            "Invalid immediate type"
        );

$display("");
        $display("ALL IMMEDIATE GENERATOR TESTS PASSED: %0d tests",
                 tests_passed);
        $finish;
    end

endmodule