
`timescale 1ns/1ps

module rv32i_noc_single_core_subsystem_tb;

    // ============================================================
    // Clock and reset
    // ============================================================
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ============================================================
    // Instruction interface
    // ============================================================
    logic [31:0] instruction_address;
    logic [31:0] instruction_data;

    // ============================================================
    // Retirement interface
    // ============================================================
    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [31:0] retire_instruction;
    logic        retire_rd_we;
    logic [4:0]  retire_rd;
    logic [31:0] retire_rd_data;

    // ============================================================
    // Integration debug signals
    // ============================================================
    logic        memory_request_active;
    logic        memory_response_active;
    logic [3:0]  fabric_protocol_errors;

    // ============================================================
    // Architectural register scoreboard
    // ============================================================
    logic [31:0] observed_regs [0:31];

    integer retire_count;
    integer store_retire_count;
    integer load_retire_count;
    integer memory_wait_cycles;

    logic [31:0] previous_memory_pc;
    logic        previous_pc_was_memory;

    integer i;

    // ============================================================
    // Test program
    //
    // Address  Instruction             Expected effect
    // 0x00     ADDI x1, x0, 85          x1 = 85
    // 0x04     ADDI x2, x0, 32          x2 = 32
    // 0x08     SW   x1, 0(x2)           MEM[32] = 85
    // 0x0C     LW   x3, 0(x2)           x3 = MEM[32]
    // 0x10     ADDI x4, x3, 1           x4 = 86
    // 0x14+    NOP
    //
    // Data memory resides at NoC node (1,1).
    // CPU is attached to NoC node (0,0).
    // ============================================================
    always @(*) begin
        case (instruction_address)
            32'h00000000: instruction_data = 32'h05500093;
            32'h00000004: instruction_data = 32'h02000113;
            32'h00000008: instruction_data = 32'h00112023;
            32'h0000000C: instruction_data = 32'h00012183;
            32'h00000010: instruction_data = 32'h00118213;
            default:      instruction_data = 32'h00000013;
        endcase
    end

    // ============================================================
    // Device under test
    // ============================================================
    rv32i_noc_single_core_subsystem #(
        .CPU_NODE(0),
        .FIFO_DEPTH(8),
        .MEM_BYTES(1024)
    ) dut (
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

        .memory_request_active(memory_request_active),
        .memory_response_active(memory_response_active),
        .fabric_protocol_errors(fabric_protocol_errors)
    );

    // ============================================================
    // Retirement monitor and architectural scoreboard
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            retire_count          <= 0;
            store_retire_count    <= 0;
            load_retire_count     <= 0;
            memory_wait_cycles    <= 0;
            previous_memory_pc    <= 32'hFFFFFFFF;
            previous_pc_was_memory <= 1'b0;

            for (integer k = 0; k < 32; k = k + 1)
                observed_regs[k] <= 32'd0;
        end else begin

            // Count consecutive cycles spent at the same load/store PC.
            if ((instruction_address == 32'h00000008) ||
                (instruction_address == 32'h0000000C)) begin

                if (previous_pc_was_memory &&
                    instruction_address == previous_memory_pc)
                    memory_wait_cycles <= memory_wait_cycles + 1;

                previous_memory_pc     <= instruction_address;
                previous_pc_was_memory <= 1'b1;
            end else begin
                previous_memory_pc     <= 32'hFFFFFFFF;
                previous_pc_was_memory <= 1'b0;
            end

            // Record architectural register writes at retirement.
            if (retire_valid) begin
                retire_count <= retire_count + 1;

                $display(
                    "RETIRE pc=%08h instruction=%08h rd_we=%b rd=%0d data=%08h",
                    retire_pc,
                    retire_instruction,
                    retire_rd_we,
                    retire_rd,
                    retire_rd_data
                );

                if (retire_rd_we && retire_rd != 5'd0)
                    observed_regs[retire_rd] <= retire_rd_data;

                if (retire_pc == 32'h00000008)
                    store_retire_count <= store_retire_count + 1;

                if (retire_pc == 32'h0000000C)
                    load_retire_count <= load_retire_count + 1;
            end
        end
    end

    // ============================================================
    // Main test sequence
    // ============================================================
    initial begin
        $dumpfile("sim/rv32i_noc_single_core_subsystem_tb.vcd");
        $dumpvars(0, rv32i_noc_single_core_subsystem_tb);

        rst_n = 1'b0;

        retire_count           = 0;
        store_retire_count     = 0;
        load_retire_count      = 0;
        memory_wait_cycles     = 0;
        previous_memory_pc     = 32'hFFFFFFFF;
        previous_pc_was_memory = 1'b0;

        for (i = 0; i < 32; i = i + 1)
            observed_regs[i] = 32'd0;

        $display("");
        $display("==================================================");
        $display("RV32I CPU + 2x2 NoC MEMORY INTEGRATION TEST");
        $display("==================================================");

        // Hold reset for three rising clock edges.
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        $display("Reset released at time %0t", $time);

        // Wait until the fifth instruction writes x4 = 86.
        // Timeout below prevents a failed design hanging forever.
        wait (observed_regs[4] == 32'd86);

        // Let the scoreboard's nonblocking assignments settle.
        repeat (3) @(posedge clk);
        #1;

        $display("");
        $display("Checking architectural results...");

        if (observed_regs[1] !== 32'd85)
            $fatal(1, "FAIL: x1 expected 85, got %08h",
                   observed_regs[1]);
        else
            $display("PASS: x1 = 85");

        if (observed_regs[2] !== 32'd32)
            $fatal(1, "FAIL: x2 expected 32, got %08h",
                   observed_regs[2]);
        else
            $display("PASS: x2 = 32");

        if (observed_regs[3] !== 32'd85)
            $fatal(1, "FAIL: x3 expected 85, got %08h",
                   observed_regs[3]);
        else
            $display("PASS: x3 = 85 (loaded through the NoC)");

        if (observed_regs[4] !== 32'd86)
            $fatal(1, "FAIL: x4 expected 86, got %08h",
                   observed_regs[4]);
        else
            $display("PASS: x4 = 86");

        if (store_retire_count != 1)
            $fatal(1, "FAIL: store retired %0d times; expected 1",
                   store_retire_count);
        else
            $display("PASS: store retired exactly once");

        if (load_retire_count != 1)
            $fatal(1, "FAIL: load retired %0d times; expected 1",
                   load_retire_count);
        else
            $display("PASS: load retired exactly once");

        if (memory_wait_cycles < 2)
            $fatal(1,
                   "FAIL: PC did not remain on memory instructions long enough; observed %0d repeated-PC cycles",
                   memory_wait_cycles);
        else
            $display(
                "PASS: CPU held its PC while waiting (%0d repeated-PC cycles)",
                memory_wait_cycles
            );

        if (fabric_protocol_errors !== 4'b0000)
            $fatal(1, "FAIL: fabric protocol errors = %b",
                   fabric_protocol_errors);
        else
            $display("PASS: no NoC protocol errors");

        $display("");
        $display("==================================================");
        $display("ALL CPU + NOC INTEGRATION CHECKS PASSED");
        $display("Retired instructions observed: %0d", retire_count);
        $display("==================================================");

        $finish;
    end

    // ============================================================
    // Global timeout
    // ============================================================
    initial begin
        #20000;
        $fatal(1,
               "TIMEOUT: CPU + NoC integration test did not complete");
    end

endmodule
