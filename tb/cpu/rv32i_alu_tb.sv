`timescale 1ns/1ps

module rv32i_alu_tb;

logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [3:0]  alu_control;
    logic [31:0] result;
    logic        zero;

    integer tests_passed;

localparam logic [3:0] ALU_ADD  = 4'b0000;
    localparam logic [3:0] ALU_SUB  = 4'b0001;
    localparam logic [3:0] ALU_AND  = 4'b0010;
    localparam logic [3:0] ALU_OR   = 4'b0011;
    localparam logic [3:0] ALU_XOR  = 4'b0100;
    localparam logic [3:0] ALU_SLT  = 4'b0101;
    localparam logic [3:0] ALU_SLTU = 4'b0110;
    localparam logic [3:0] ALU_SLL  = 4'b0111;
    localparam logic [3:0] ALU_SRL  = 4'b1000;
    localparam logic [3:0] ALU_SRA  = 4'b1001;

rv32i_alu dut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .alu_control(alu_control),
        .result(result),
        .zero(zero)
    );

task check_result;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            #1;
            if (result !== expected) begin
                $display("FAIL: %0s", test_name);
                $display("Expected: %h, got: %h", expected, result);
                $fatal(1, "ALU result mismatch");
            end

if (zero !== (expected == 32'b0))
                $fatal(1, "Incorrect zero flag: %0s", test_name);

tests_passed = tests_passed + 1;
            $display("PASS: %0s -> %h", test_name, result);
        end
    endtask

initial begin
        operand_a = 0;
        operand_b = 0;
        alu_control = ALU_ADD;
        tests_passed = 0;

        $display("Starting RV32I ALU tests");

operand_a = 32'd10;
        operand_b = 32'd5;
        alu_control = ALU_ADD;
        check_result(32'd15, "ADD");

operand_a = 32'd10;
        operand_b = 32'd5;
        alu_control = ALU_SUB;
        check_result(32'd5, "SUB");

operand_a = 32'hF0F0_0000;
        operand_b = 32'h0FF0_0000;
        alu_control = ALU_AND;
        check_result(32'h00F0_0000, "AND");

operand_a = 32'hF000_0000;
        operand_b = 32'h0000_000F;
        alu_control = ALU_OR;
        check_result(32'hF000_000F, "OR");

operand_a = 32'hAAAA_5555;
        operand_b = 32'hFFFF_0000;
        alu_control = ALU_XOR;
        check_result(32'h5555_5555, "XOR");

operand_a = -32'sd5;
        operand_b = 32'd3;
        alu_control = ALU_SLT;
        check_result(32'd1, "SLT signed");

operand_a = 32'hFFFF_FFFF;
        operand_b = 32'd1;
        alu_control = ALU_SLTU;
        check_result(32'd0, "SLTU unsigned");

operand_a = 32'd1;
        operand_b = 32'd4;
        alu_control = ALU_SLL;
        check_result(32'd16, "SLL");

operand_a = 32'h8000_0000;
        operand_b = 32'd1;
        alu_control = ALU_SRL;
        check_result(32'h4000_0000, "SRL");

operand_a = 32'h8000_0000;
        operand_b = 32'd1;
        alu_control = ALU_SRA;
        check_result(32'hC000_0000, "SRA");

operand_a = 32'd7;
        operand_b = 32'd7;
        alu_control = ALU_SUB;
        check_result(32'd0, "Zero result");

$display("");
        $display("ALL ALU TESTS PASSED: %0d tests", tests_passed);
        $finish;
    end

endmodule