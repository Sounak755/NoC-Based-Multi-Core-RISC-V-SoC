
`timescale 1ns/1ps

module rv32i_core_tb;

    logic clk = 0;
    logic rst_n = 0;

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

    rv32i_core dut (
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

    // Combinational instruction ROM
    always @(*) begin
        case (instruction_address)
            32'd0:  instruction_data = 32'h00500093; // addi x1,x0,5
            32'd4:  instruction_data = 32'h00A00113; // addi x2,x0,10
            32'd8:  instruction_data = 32'h002081B3; // add x3,x1,x2
            32'd12: instruction_data = 32'hFFD18213; // addi x4,x3,-3
            32'd16: instruction_data = 32'h00318463; // beq x3,x3,+8
            32'd20: instruction_data = 32'h06300293; // skipped: addi x5,x0,99
            32'd24: instruction_data = 32'h00700293; // addi x5,x0,7
            32'd28: instruction_data = 32'h0080036F; // jal x6,+8
            32'd32: instruction_data = 32'h06300393; // skipped: addi x7,x0,99
            32'd36: instruction_data = 32'h12345437; // lui x8,0x12345
            32'd40: instruction_data = 32'h00001497; // auipc x9,0x1
            default: instruction_data = 32'h00000013; // nop
        endcase
    end

    // Track architectural register writes
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
        $dumpfile("sim/rv32i_core_tb.vcd");
        $dumpvars(0, rv32i_core_tb);

        $display("Starting RV32I core testbench...");

        for (i = 0; i < 32; i = i + 1)
            observed_regs[i] = 32'b0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        $display("Reset released at time %0t", $time);

        // Allow arithmetic, branch, jump, LUI and AUIPC to execute.
        repeat (12) @(negedge clk);

        $display("");
        $display("Checking architectural results...");

        if (observed_regs[1] !== 32'd5)
            $fatal(1, "FAIL: x1 expected 5, got %0d", observed_regs[1]);

        if (observed_regs[2] !== 32'd10)
            $fatal(1, "FAIL: x2 expected 10, got %0d", observed_regs[2]);

        if (observed_regs[3] !== 32'd15)
            $fatal(1, "FAIL: x3 expected 15, got %0d", observed_regs[3]);

        if (observed_regs[4] !== 32'd12)
            $fatal(1, "FAIL: x4 expected 12, got %0d", observed_regs[4]);

        if (observed_regs[5] !== 32'd7)
            $fatal(1, "FAIL: x5 expected 7, got %0d", observed_regs[5]);

        if (observed_regs[6] !== 32'd32)
            $fatal(1, "FAIL: x6 expected link address 32, got %0d",
                   observed_regs[6]);

        if (observed_regs[7] !== 32'd0)
            $fatal(1, "FAIL: skipped instruction check failed; x7=%0d",
                   observed_regs[7]);

        if (observed_regs[8] !== 32'h12345000)
            $fatal(1, "FAIL: x8 LUI expected 12345000, got %08h",
                   observed_regs[8]);

        if (observed_regs[9] !== 32'h00001028)
            $fatal(1, "FAIL: x9 AUIPC expected 00001028, got %08h",
                   observed_regs[9]);

        if (retire_count < 8)
            $fatal(1, "FAIL: too few retired instructions: %0d",
                   retire_count);

        $display("");
        $display("PASS: x1 = %0d", observed_regs[1]);
        $display("PASS: x2 = %0d", observed_regs[2]);
        $display("PASS: x3 = %0d", observed_regs[3]);
        $display("PASS: x4 = %0d", observed_regs[4]);
        $display("PASS: x5 = %0d", observed_regs[5]);
        $display("PASS: x6 = %0d (JAL link)", observed_regs[6]);
        $display("PASS: x7 = 0 (skipped instructions)");
        $display("PASS: x8 = %08h (LUI)", observed_regs[8]);
        $display("PASS: x9 = %08h (AUIPC)", observed_regs[9]);
        $display("Retired instructions: %0d", retire_count);
        $display("ALL CPU CORE TESTS PASSED");

        $finish;
    end

    initial begin
        #500;
        $fatal(1, "FAIL: simulation timeout");
    end

endmodule
