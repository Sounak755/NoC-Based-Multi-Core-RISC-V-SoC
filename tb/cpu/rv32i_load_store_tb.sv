
`timescale 1ns/1ps

module rv32i_load_store_tb;

    logic clk;
    logic rst_n;

    logic [31:0] instruction_address;
    logic [31:0] instruction_data;

    logic retire_valid;
    logic [31:0] retire_pc;
    logic [31:0] retire_instruction;
    logic retire_rd_we;
    logic [4:0] retire_rd;
    logic [31:0] retire_rd_data;

    logic data_memory_read_enable;
    logic data_memory_write_enable;
    logic [2:0] data_memory_funct3;
    logic [31:0] data_memory_address;
    logic [31:0] data_memory_write_data;
    logic [31:0] data_memory_read_data;

    logic [31:0] program_memory [0:63];
    logic [31:0] observed_regs [0:31];

    integer i;
    integer retired_count;

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
        .retire_rd_data(retire_rd_data),

        .data_memory_read_enable(data_memory_read_enable),
        .data_memory_write_enable(data_memory_write_enable),
        .data_memory_funct3(data_memory_funct3),
        .data_memory_address(data_memory_address),
        .data_memory_write_data(data_memory_write_data),
        .data_memory_read_data(data_memory_read_data)
    );

    rv32i_data_memory #(
        .DEPTH_WORDS(256)
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

    // Clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Instruction memory: combinational read
    always @(*) begin
        if ((instruction_address[31:2] < 64) &&
            (instruction_address[1:0] == 2'b00)) begin
            instruction_data = program_memory[instruction_address[7:2]];
        end
        else begin
            instruction_data = 32'h00000013; // NOP
        end
    end

    // Program and register observation initialization
    initial begin
        for (i = 0; i < 64; i = i + 1)
            program_memory[i] = 32'h00000013;

        for (i = 0; i < 32; i = i + 1)
            observed_regs[i] = 32'b0;

        retired_count = 0;

        // x1 = 64: base address
        program_memory[0]  = 32'h04000093; // ADDI x1,x0,64

        // x2 = 0x123
        program_memory[1]  = 32'h12300113; // ADDI x2,x0,0x123

        // Store and load word
        program_memory[2]  = 32'h0020A023; // SW x2,0(x1)
        program_memory[3]  = 32'h0000A183; // LW x3,0(x1)

        // Store 0xFF into byte offset 1
        program_memory[4]  = 32'hFFF00213; // ADDI x4,x0,-1
        program_memory[5]  = 32'h004080A3; // SB x4,1(x1)

        // Signed and unsigned byte loads
        program_memory[6]  = 32'h00108283; // LB x5,1(x1)
        program_memory[7]  = 32'h0010C303; // LBU x6,1(x1)

        // Store halfword 0x123 at byte offset 2
        program_memory[8]  = 32'h00209123; // SH x2,2(x1)

        // Signed and unsigned halfword loads
        program_memory[9]  = 32'h00209383; // LH x7,2(x1)
        program_memory[10] = 32'h0020D403; // LHU x8,2(x1)

        // Verify the final word
        program_memory[11] = 32'h0000A483; // LW x9,0(x1)

        // Reset
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Allow program to execute
        repeat (20) @(posedge clk);
        #1;

        $display("");
        $display("===== RV32I LOAD/STORE TEST RESULTS =====");

        if (observed_regs[3] === 32'h00000123)
            $display("PASS: LW returned 0x00000123");
        else
            $display("FAIL: LW x3 = %h, expected 00000123",
                     observed_regs[3]);

        if (observed_regs[5] === 32'hFFFFFFFF)
            $display("PASS: LB sign-extended 0xFF");
        else
            $display("FAIL: LB x5 = %h, expected FFFFFFFF",
                     observed_regs[5]);

        if (observed_regs[6] === 32'h000000FF)
            $display("PASS: LBU zero-extended 0xFF");
        else
            $display("FAIL: LBU x6 = %h, expected 000000FF",
                     observed_regs[6]);

        if (observed_regs[7] === 32'h00000123)
            $display("PASS: LH returned 0x00000123");
        else
            $display("FAIL: LH x7 = %h, expected 00000123",
                     observed_regs[7]);

        if (observed_regs[8] === 32'h00000123)
            $display("PASS: LHU returned 0x00000123");
        else
            $display("FAIL: LHU x8 = %h, expected 00000123",
                     observed_regs[8]);

        if (observed_regs[9] === 32'h0123FF23)
            $display("PASS: Final LW returned 0x0123FF23");
        else
            $display("FAIL: Final LW x9 = %h, expected 0123FF23",
                     observed_regs[9]);

        if (data_mem.memory[16] === 32'h0123FF23)
            $display("PASS: Data memory word 16 = 0x0123FF23");
        else
            $display("FAIL: Memory word 16 = %h, expected 0123FF23",
                     data_mem.memory[16]);

        $display("Retired instructions observed: %0d", retired_count);
        $display("========================================");
        $finish;
    end

    // Observe committed register writes
    always @(posedge clk) begin
        if (rst_n && retire_valid) begin
            retired_count <= retired_count + 1;

            if (retire_rd_we && retire_rd != 5'd0)
                observed_regs[retire_rd] <= retire_rd_data;
        end
    end

    // Timeout guard
    initial begin
        #1000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
