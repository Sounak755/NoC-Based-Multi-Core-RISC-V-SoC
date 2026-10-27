
`timescale 1ns/1ps

module noc_memory_endpoint_tb;

    logic clk = 0;
    logic rst_n = 0;

    logic req_valid = 0;
    logic req_ready;
    logic req_write = 0;
    logic [2:0] req_funct3 = 0;
    logic [31:0] req_addr = 0;
    logic [31:0] req_wdata = 0;

    logic resp_valid;
    logic resp_ready = 0;
    logic [31:0] resp_rdata;
    logic resp_error;

    integer checks = 0;
    integer errors = 0;

    always #5 clk = ~clk;

    noc_memory_endpoint #(
        .MEM_BYTES(256)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_funct3(req_funct3),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .resp_valid(resp_valid),
        .resp_ready(resp_ready),
        .resp_rdata(resp_rdata),
        .resp_error(resp_error)
    );

    task automatic check(
        input logic condition,
        input string message
    );
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL [%0d]: %s", checks, message);
            end else begin
                $display("PASS [%0d]: %s", checks, message);
            end
        end
    endtask

    task automatic transact(
        input logic write_op,
        input logic [2:0] funct3,
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [31:0] expected_data,
        input logic expected_error,
        input string message
    );
        integer timeout_count;
        begin
            @(negedge clk);
            req_write  = write_op;
            req_funct3 = funct3;
            req_addr   = address;
            req_wdata  = data;
            req_valid  = 1'b1;
            resp_ready = 1'b0;

            timeout_count = 0;
            while (req_ready !== 1'b1 && timeout_count < 20) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            check(req_ready, {message, " request ready"});

            @(posedge clk);
            #1;
            @(negedge clk);
            req_valid = 1'b0;

            timeout_count = 0;
            while (resp_valid !== 1'b1 && timeout_count < 20) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            check(resp_valid, {message, " response valid"});
            check(resp_error === expected_error,
                  {message, " error flag"});
            check(resp_rdata === expected_data,
                  {message, " response data"});

            @(negedge clk);
            resp_ready = 1'b1;
            @(posedge clk);
            #1;
            @(negedge clk);
            resp_ready = 1'b0;
        end
    endtask

    initial begin
        $display("");
        $display("========================================");
        $display("NOC MEMORY ENDPOINT TESTS");
        $display("========================================");

        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        check(req_ready === 1'b1, "Ready after reset");
        check(resp_valid === 1'b0, "No response after reset");

        // Word store followed by word load.
        transact(1'b1, 3'b010, 32'd16, 32'h89ABCDEF,
                 32'b0, 1'b0, "SW address 16");

        transact(1'b0, 3'b010, 32'd16, 32'b0,
                 32'h89ABCDEF, 1'b0, "LW address 16");

        // Signed and unsigned byte loads.
        transact(1'b1, 3'b000, 32'd20, 32'h00000080,
                 32'b0, 1'b0, "SB address 20");

        transact(1'b0, 3'b000, 32'd20, 32'b0,
                 32'hFFFFFF80, 1'b0, "LB sign extension");

        transact(1'b0, 3'b100, 32'd20, 32'b0,
                 32'h00000080, 1'b0, "LBU zero extension");

        // Halfword store/load and extension.
        transact(1'b1, 3'b001, 32'd24, 32'h00008001,
                 32'b0, 1'b0, "SH address 24");

        transact(1'b0, 3'b001, 32'd24, 32'b0,
                 32'hFFFF8001, 1'b0, "LH sign extension");

        transact(1'b0, 3'b101, 32'd24, 32'b0,
                 32'h00008001, 1'b0, "LHU zero extension");

        // Misaligned and out-of-range requests.
        transact(1'b0, 3'b010, 32'd17, 32'b0,
                 32'b0, 1'b1, "Misaligned LW");

        transact(1'b0, 3'b001, 32'd25, 32'b0,
                 32'b0, 1'b1, "Misaligned LH");

        transact(1'b0, 3'b010, 32'd254, 32'b0,
                 32'b0, 1'b1, "Out-of-range LW");

        // Unsupported funct3.
        transact(1'b0, 3'b011, 32'd16, 32'b0,
                 32'b0, 1'b1, "Unsupported load funct3");

        // Verify response stability under backpressure.
        @(negedge clk);
        req_write  = 1'b0;
        req_funct3 = 3'b010;
        req_addr   = 32'd16;
        req_wdata  = 32'b0;
        req_valid  = 1'b1;
        resp_ready = 1'b0;

        @(posedge clk);
        #1;
        @(negedge clk);
        req_valid = 1'b0;

        wait (resp_valid === 1'b1);
        repeat (4) begin
            @(negedge clk);
            check(resp_valid === 1'b1,
                  "Response held during backpressure");
            check(resp_rdata === 32'h89ABCDEF,
                  "Response data stable during backpressure");
        end

        resp_ready = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        resp_ready = 1'b0;

        check(resp_valid === 1'b0, "Response clears after handshake");

        $display("");
        $display("========================================");
        if (errors == 0)
            $display("ALL MEMORY ENDPOINT TESTS PASSED");
        else
            $display("MEMORY ENDPOINT TESTS FAILED");

        $display("Total checks: %0d", checks);
        $display("Failures: %0d", errors);
        $display("========================================");

        $finish;
    end

    initial begin
        #20000;
        $display("FATAL: Testbench timeout");
        $finish;
    end

endmodule
