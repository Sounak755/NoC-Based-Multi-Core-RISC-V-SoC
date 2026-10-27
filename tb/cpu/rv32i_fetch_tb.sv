`timescale 1ns/1ps

module rv32i_fetch_tb;

    logic clk;
    logic rst_n;
    logic [31:0] next_pc;
    logic [31:0] pc;
    logic [31:0] instruction;

    integer tests_passed;

    localparam logic [31:0] NOP = 32'h00000013;

    rv32i_pc pc_unit (
        .clk(clk),
        .rst_n(rst_n),
        .next_pc(next_pc),
        .pc(pc)
    );

    rv32i_instruction_memory #(
        .DEPTH_WORDS(64)
    ) instruction_memory (
        .address(pc),
        .instruction(instruction)
    );

    always #5 clk = ~clk;

    task check_pc;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            #1;
            if (pc !== expected) begin
                $display("FAIL: %0s", test_name);
                $display("Expected PC: %08h", expected);
                $display("Actual PC:   %08h", pc);
                $fatal(1, "Program counter mismatch");
            end

            tests_passed = tests_passed + 1;
            $display("PASS: %0s -> PC=%08h", test_name, pc);
        end
    endtask

    task check_instruction;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            #1;
            if (instruction !== expected) begin
                $display("FAIL: %0s", test_name);
                $display("Expected instruction: %08h", expected);
                $display("Actual instruction:   %08h", instruction);
                $fatal(1, "Instruction fetch mismatch");
            end

            tests_passed = tests_passed + 1;
            $display("PASS: %0s -> %08h", test_name, instruction);
        end
    endtask

    task advance_pc;
        input [31:0] target;
        begin
            @(negedge clk);
            next_pc = target;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        next_pc = 32'b0;
        tests_passed = 0;

        $display("Starting RV32I PC and instruction-fetch tests");

        // Reset the PC.
        @(posedge clk);
        #1;
        check_pc(32'h00000000, "PC reset");

        @(negedge clk);
        rst_n = 1'b1;

        // Fetch instruction at address zero.
        check_instruction(32'h00500093, "Fetch ADDI x1");

        // Sequential execution: PC advances by four.
        advance_pc(32'h00000004);
        check_pc(32'h00000004, "Sequential PC + 4");
        check_instruction(32'h00A00113, "Fetch ADDI x2");

        advance_pc(32'h00000008);
        check_pc(32'h00000008, "Second sequential PC + 4");
        check_instruction(32'h002081B3, "Fetch ADD");

        advance_pc(32'h0000000C);
        check_instruction(NOP, "Fetch NOP");

        // Load a jump/branch target.
        advance_pc(32'h00000000);
        check_pc(32'h00000000, "Load jump target");
        check_instruction(32'h00500093, "Fetch after jump");

        // Unaligned and out-of-range addresses return NOP.
        advance_pc(32'h00000002);
        check_instruction(NOP, "Unaligned address");

        advance_pc(32'h00001000);
        check_instruction(NOP, "Out-of-range address");

        $display("");
        $display("ALL PC AND FETCH TESTS PASSED: %0d tests", tests_passed);
        $finish;
    end

endmodule