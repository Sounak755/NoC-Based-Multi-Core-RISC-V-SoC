
`timescale 1ns/1ps

module rv32i_core_imem_tb;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic [31:0] instruction_address;
    logic [31:0] instruction_data;

    logic retire_valid;
    logic [31:0] retire_pc;
    logic [31:0] retire_instruction;
    logic retire_rd_we;
    logic [4:0] retire_rd;
    logic [31:0] retire_rd_data;

    logic [31:0] observed_regs [0:31];
    integer retire_count = 0;
    integer i;

    always #5 clk = ~clk;

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
        .retire_rd_data(retire_rd_data)
    );

    rv32i_instruction_memory #(
        .DEPTH_WORDS(64)
    ) instruction_memory (
        .address(instruction_address),
        .instruction(instruction_data)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            retire_count = 0;

            for (integer k = 0; k < 32; k = k + 1)
                observed_regs[k] = 32'b0;
        end
        else if (retire_valid) begin
            retire_count = retire_count + 1;

            if (retire_rd_we && retire_rd != 0)
                observed_regs[retire_rd] = retire_rd_data;

            $display(
                "RETIRE pc=%08h instruction=%08h rd_we=%b rd=%0d data=%08h",
                retire_pc,
                retire_instruction,
                retire_rd_we,
                retire_rd,
                retire_rd_data
            );
        end
    end

    initial begin
        $dumpfile("sim/rv32i_core_imem_tb.vcd");
        $dumpvars(0, rv32i_core_imem_tb);

        $display("========================================");
        $display("RV32I CPU + INSTRUCTION MEMORY TEST");
        $display("========================================");

        for (i = 0; i < 32; i = i + 1)
            observed_regs[i] = 32'b0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        $display("Reset released at time %0t", $time);

        repeat (8) @(negedge clk);

        $display("");
        $display("Checking results from instruction memory...");

        if (observed_regs[1] !== 32'd5)
            $fatal(1, "FAIL: x1 expected 5, got %0d",
                   observed_regs[1]);

        if (observed_regs[2] !== 32'd10)
            $fatal(1, "FAIL: x2 expected 10, got %0d",
                   observed_regs[2]);

        if (observed_regs[3] !== 32'd15)
            $fatal(1, "FAIL: x3 expected 15, got %0d",
                   observed_regs[3]);

        if (retire_count < 3)
            $fatal(1, "FAIL: expected at least 3 retired instructions, got %0d",
                   retire_count);

        $display("PASS: x1 = %0d", observed_regs[1]);
        $display("PASS: x2 = %0d", observed_regs[2]);
        $display("PASS: x3 = %0d (5 + 10)", observed_regs[3]);
        $display("Retired instructions: %0d", retire_count);
        $display("ALL CPU + INSTRUCTION MEMORY TESTS PASSED");

        $finish;
    end

    initial begin
        #500;
        $fatal(1, "FAIL: simulation timeout");
    end

endmodule
