
`timescale 1ns/1ps

module rv32i_single_core_subsystem_tb;

    // ============================================================
    // 1. Clock and reset
    // ============================================================
    logic clk;
    logic rst_n;

    // ============================================================
    // 2. Instruction memory interface
    // ============================================================
    logic [31:0] instruction_address;
    logic [31:0] instruction_data;

    // ============================================================
    // 3. Data memory interface
    // ============================================================
    logic        data_memory_read_enable;
    logic        data_memory_write_enable;
    logic [2:0]  data_memory_funct3;
    logic [31:0] data_memory_address;
    logic [31:0] data_memory_write_data;
    logic [31:0] data_memory_read_data;

    // ============================================================
    // 4. Retirement interface
    // ============================================================
    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [31:0] retire_instruction;
    logic        retire_rd_we;
    logic [4:0]  retire_rd;
    logic [31:0] retire_rd_data;

    // ============================================================
    // 5. Testbench tracking
    // ============================================================
    logic [31:0] observed_regs [0:31];

    integer i;
    integer retire_count;
    integer failure_count;

    // ============================================================
    // 6. Device under test
    // ============================================================
    rv32i_single_core_subsystem #(
        .IMEM_DEPTH_WORDS(64),
        .DMEM_DEPTH_WORDS(256)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .instruction_address(instruction_address),
        .instruction_data(instruction_data),

        .data_memory_read_enable(data_memory_read_enable),
        .data_memory_write_enable(data_memory_write_enable),
        .data_memory_funct3(data_memory_funct3),
        .data_memory_address(data_memory_address),
        .data_memory_write_data(data_memory_write_data),
        .data_memory_read_data(data_memory_read_data),

        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_instruction(retire_instruction),
        .retire_rd_we(retire_rd_we),
        .retire_rd(retire_rd),
        .retire_rd_data(retire_rd_data)
    );

    // ============================================================
    // 7. Clock generation: 10 ns period
    // ============================================================
    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;

    // ============================================================
    // 8. Monitor retired instructions and register writes
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            retire_count <= 0;
        end
        else if (retire_valid) begin
            retire_count <= retire_count + 1;

            $display(
                "RETIRE pc=%08h instruction=%08h rd_we=%b rd=%0d data=%08h",
                retire_pc,
                retire_instruction,
                retire_rd_we,
                retire_rd,
                retire_rd_data
            );

            if (retire_rd_we && (retire_rd != 5'd0)) begin
                observed_regs[retire_rd] <= retire_rd_data;
            end
        end
    end

    // ============================================================
    // 9. Main test sequence
    // ============================================================
    initial begin
        $dumpfile("sim/rv32i_single_core_subsystem_tb.vcd");
        $dumpvars(0, rv32i_single_core_subsystem_tb);

        failure_count = 0;
        retire_count  = 0;

        for (i = 0; i < 32; i = i + 1) begin
            observed_regs[i] = 32'b0;
        end

        $display("==============================================");
        $display("RV32I SINGLE-CORE SUBSYSTEM TEST");
        $display("==============================================");

        // Assert active-low reset.
        rst_n = 1'b0;

        repeat (3) @(posedge clk);

        // Release reset away from the active clock edge.
        @(negedge clk);
        rst_n = 1'b1;

        $display("Reset released at time %0t", $time);

        // Default program:
        // ADDI x1, x0, 5
        // ADDI x2, x0, 10
        // ADD  x3, x1, x2
        // NOP
        repeat (12) @(posedge clk);

        // Allow nonblocking assignments to settle.
        #1;

        $display("");
        $display("Checking architectural results...");
        $display("");

        // --------------------------------------------------------
        // Check x1
        // --------------------------------------------------------
        if (observed_regs[1] === 32'd5) begin
            $display("PASS: x1 = 5");
        end
        else begin
            $display(
                "FAIL: x1 = %08h, expected 00000005",
                observed_regs[1]
            );
            failure_count = failure_count + 1;
        end

        // --------------------------------------------------------
        // Check x2
        // --------------------------------------------------------
        if (observed_regs[2] === 32'd10) begin
            $display("PASS: x2 = 10");
        end
        else begin
            $display(
                "FAIL: x2 = %08h, expected 0000000A",
                observed_regs[2]
            );
            failure_count = failure_count + 1;
        end

        // --------------------------------------------------------
        // Check x3 = x1 + x2
        // --------------------------------------------------------
        if (observed_regs[3] === 32'd15) begin
            $display("PASS: x3 = 15 (5 + 10)");
        end
        else begin
            $display(
                "FAIL: x3 = %08h, expected 0000000F",
                observed_regs[3]
            );
            failure_count = failure_count + 1;
        end

        // --------------------------------------------------------
        // Check retirement activity
        // --------------------------------------------------------
        if (retire_count >= 3) begin
            $display(
                "PASS: Retirement interface active (%0d instructions)",
                retire_count
            );
        end
        else begin
            $display(
                "FAIL: Only %0d instructions retired; expected at least 3",
                retire_count
            );
            failure_count = failure_count + 1;
        end

        // --------------------------------------------------------
        // Final summary
        // --------------------------------------------------------
        $display("");
        $display("==============================================");

        if (failure_count == 0) begin
            $display("ALL SINGLE-CORE SUBSYSTEM TESTS PASSED");
        end
        else begin
            $display(
                "SINGLE-CORE SUBSYSTEM TEST FAILED: %0d failure(s)",
                failure_count
            );
        end

        $display("Retired instructions: %0d", retire_count);
        $display("==============================================");

        $finish;
    end

    // ============================================================
    // 10. Simulation timeout
    // ============================================================
    initial begin
        #1000;
        $display("ERROR: Single-core subsystem testbench timed out.");
        $finish;
    end

endmodule
