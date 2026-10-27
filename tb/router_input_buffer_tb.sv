`timescale 1ns/1ps

module router_input_buffer_tb;

    localparam int DATA_WIDTH = 32;
    localparam int DEPTH = 4;

    logic clk;
    logic rst_n;

    logic [DATA_WIDTH-1:0] data_in;
    logic valid_in;
    logic ready_in;

    logic [DATA_WIDTH-1:0] data_out;
    logic valid_out;
    logic ready_out;

    router_input_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .data_out(data_out),
        .valid_out(valid_out),
        .ready_out(ready_out)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/router_input_buffer.vcd");
        $dumpvars(0, router_input_buffer_tb);

        clk = 0;
        rst_n = 0;
        data_in = 0;
        valid_in = 0;
        ready_out = 0;

        // Reset
        repeat (2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // Test 1: FIFO initially empty
        if (!valid_out)
            $display("PASS: FIFO initially empty");
        else
            $fatal(1, "FAIL: FIFO should be empty");

        // Test 2: Send packet A
        data_in = 32'hAAAA_0001;
        valid_in = 1;
        #1;
        if (!ready_in)
            $fatal(1, "FAIL: FIFO should accept packet A");

        @(posedge clk);
        @(negedge clk);
        valid_in = 0;

        if (valid_out && data_out == 32'hAAAA_0001)
            $display("PASS: Packet A buffered correctly");
        else
            $fatal(1, "FAIL: Packet A missing or corrupted");

        // Test 3: Stall downstream and buffer packet B
        data_in = 32'hBBBB_0002;
        valid_in = 1;
        ready_out = 0;

        @(posedge clk);
        @(negedge clk);
        valid_in = 0;

        if (valid_out && data_out == 32'hAAAA_0001)
            $display("PASS: Packet A held during downstream stall");
        else
            $fatal(1, "FAIL: Head packet changed during stall");

        // Test 4: Release stall; packet A must emerge first
        ready_out = 1;

        @(posedge clk);
        @(negedge clk);

        if (valid_out && data_out == 32'hBBBB_0002)
            $display("PASS: Packet B follows packet A");
        else
            $fatal(1, "FAIL: FIFO ordering incorrect");

        // Consume packet B
        @(posedge clk);
        @(negedge clk);

        if (!valid_out)
            $display("PASS: FIFO empty after both packets consumed");
        else
            $fatal(1, "FAIL: FIFO should now be empty");

        valid_in = 0;
        ready_out = 0;

        $display("ALL INPUT BUFFER TESTS PASSED");
        $finish;
    end

endmodule