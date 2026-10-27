module rv32i_regfile_tb;

logic clk;
    logic rst_n;

logic [4:0] read_addr1;
    logic [4:0] read_addr2;
    logic [31:0] read_data1;
    logic [31:0] read_data2;

logic write_enable;
    logic [4:0] write_addr;
    logic [31:0] write_data;

    integer tests_passed;

rv32i_regfile dut (
        .clk(clk),
        .rst_n(rst_n),
        .read_addr1(read_addr1),
        .read_addr2(read_addr2),
        .read_data1(read_data1),
        .read_data2(read_data2),
        .write_enable(write_enable),
        .write_addr(write_addr),
        .write_data(write_data)
    );

    always #5 clk = ~clk;

task check_read1;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            #1;
            if (read_data1 !== expected) begin
                $display("FAIL: %0s", test_name);
                $display("Expected: %h, got: %h", expected, read_data1);
                $fatal(1, "Register file read port 1 mismatch");
            end
            tests_passed = tests_passed + 1;
            $display("PASS: %0s -> %h", test_name, read_data1);
        end
    endtask

task check_read2;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            #1;
            if (read_data2 !== expected) begin
                $display("FAIL: %0s", test_name);
                $display("Expected: %h, got: %h", expected, read_data2);
                $fatal(1, "Register file read port 2 mismatch");
            end
            tests_passed = tests_passed + 1;
            $display("PASS: %0s -> %h", test_name, read_data2);
        end
    endtask

task write_register;
        input [4:0] address;
        input [31:0] value;
        begin
            @(negedge clk);
            write_enable = 1'b1;
            write_addr = address;
            write_data = value;
            @(posedge clk);
            #1;
            write_enable = 1'b0;
        end
    endtask

initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        read_addr1 = 0;
        read_addr2 = 0;
        write_enable = 0;
        write_addr = 0;
        write_data = 0;
        tests_passed = 0;

        $display("Starting RV32I register file tests");

// Apply reset across a rising clock edge.
        @(posedge clk);
        #1;
        rst_n = 1'b1;

// x0 must always read as zero.
        read_addr1 = 0;
        read_addr2 = 0;
        check_read1(32'b0, "x0 read port 1");
        check_read2(32'b0, "x0 read port 2");

// Write and read a normal register.
        write_register(5'd1, 32'h1234_5678);
        read_addr1 = 5'd1;
        read_addr2 = 5'd1;
        check_read1(32'h1234_5678, "x1 write/read port 1");
        check_read2(32'h1234_5678, "x1 write/read port 2");

// Read two different registers simultaneously.
        write_register(5'd7, 32'hCAFE_BEEF);
        read_addr1 = 5'd1;
        read_addr2 = 5'd7;
        check_read1(32'h1234_5678, "simultaneous read: x1");
        check_read2(32'hCAFE_BEEF, "simultaneous read: x7");

// Attempts to write x0 must have no effect.
        write_register(5'd0, 32'hFFFF_FFFF);
        read_addr1 = 5'd0;
        check_read1(32'b0, "x0 remains zero after write attempt");

// Writes must not occur when write_enable is low.
        @(negedge clk);
        write_enable = 1'b0;
        write_addr = 5'd7;
        write_data = 32'h1111_1111;
        @(posedge clk);
        #1;
        read_addr1 = 5'd7;
        check_read1(32'hCAFE_BEEF, "write disabled");

// Reset must clear previously stored register values.
        @(negedge clk);
        rst_n = 1'b0;
        @(posedge clk);
        #1;
        rst_n = 1'b1;
        read_addr1 = 5'd1;
        read_addr2 = 5'd7;
        check_read1(32'b0, "reset clears x1");
        check_read2(32'b0, "reset clears x7");

$display("");
        $display("ALL REGISTER FILE TESTS PASSED: %0d tests", tests_passed);
        $finish;
    end

endmodule