
`timescale 1ns/1ps

module noc_memory_service_tb;

    logic clk = 0;
    logic rst_n = 0;

    logic req_valid = 0;
    logic req_ready;
    logic req_write = 0;
    logic [2:0] req_funct3 = 3'b010;
    logic [31:0] req_addr = 0;
    logic [31:0] req_wdata = 0;
    logic [3:0] req_src_x = 0;
    logic [3:0] req_src_y = 0;
    logic [3:0] req_dest_x = 0;
    logic [3:0] req_dest_y = 0;

    logic resp_valid;
    logic resp_ready = 0;
    logic [3:0] resp_src_x;
    logic [3:0] resp_src_y;
    logic [3:0] resp_dest_x;
    logic [3:0] resp_dest_y;
    logic [31:0] resp_rdata;
    logic resp_error;

    integer checks = 0;
    integer failures = 0;
    integer timeout_count;

    always #5 clk = ~clk;

    noc_memory_service #(
        .NODE_X(4'd1),
        .NODE_Y(4'd0),
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
        .req_src_x(req_src_x),
        .req_src_y(req_src_y),
        .req_dest_x(req_dest_x),
        .req_dest_y(req_dest_y),

        .resp_valid(resp_valid),
        .resp_ready(resp_ready),
        .resp_src_x(resp_src_x),
        .resp_src_y(resp_src_y),
        .resp_dest_x(resp_dest_x),
        .resp_dest_y(resp_dest_y),
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
                failures = failures + 1;
                $display("FAIL [%0d]: %s", checks, message);
            end else begin
                $display("PASS [%0d]: %s", checks, message);
            end
        end
    endtask

    task automatic send_request(
        input logic write_op,
        input logic [2:0] funct3,
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [3:0] source_x,
        input logic [3:0] source_y,
        input logic [3:0] destination_x,
        input logic [3:0] destination_y
    );
        begin
            @(negedge clk);
            req_write = write_op;
            req_funct3 = funct3;
            req_addr = address;
            req_wdata = data;
            req_src_x = source_x;
            req_src_y = source_y;
            req_dest_x = destination_x;
            req_dest_y = destination_y;
            req_valid = 1;

            timeout_count = 0;
            while (req_ready !== 1'b1 && timeout_count < 30) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            check(req_ready === 1'b1, "Request accepted by service");

            @(posedge clk);
            #1;
            @(negedge clk);
            req_valid = 0;
        end
    endtask

    task automatic wait_response;
        begin
            timeout_count = 0;
            while (resp_valid !== 1'b1 && timeout_count < 40) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end
            check(resp_valid === 1'b1, "Response received");
        end
    endtask

    task automatic consume_response;
        begin
            @(negedge clk);
            resp_ready = 1;
            @(posedge clk);
            #1;
            @(negedge clk);
            resp_ready = 0;
        end
    endtask

    initial begin
        $display("");
        $display("========================================");
        $display("NOC MEMORY SERVICE TESTS");
        $display("========================================");

        repeat (3) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        check(req_ready === 1'b1, "Service ready after reset");
        check(resp_valid === 1'b0, "No response after reset");

        // Store a word at this node's local memory.
        send_request(
            1'b1, 3'b010, 32'd16, 32'h1234ABCD,
            4'd0, 4'd0, 4'd1, 4'd0
        );
        wait_response();
        check(resp_error === 1'b0, "Valid store has no error");
        check(resp_src_x === 4'd0 && resp_src_y === 4'd0,
              "Store response preserves source coordinates");
        check(resp_dest_x === 4'd1 && resp_dest_y === 4'd0,
              "Store response preserves destination coordinates");
        consume_response();

        // Read back the stored word.
        send_request(
            1'b0, 3'b010, 32'd16, 32'd0,
            4'd0, 4'd0, 4'd1, 4'd0
        );
        wait_response();
        check(resp_error === 1'b0, "Valid load has no error");
        check(resp_rdata === 32'h1234ABCD,
              "Load returns previously stored word");
        consume_response();

        // Destination does not match this service's configured node.
        send_request(
            1'b0, 3'b010, 32'd16, 32'd0,
            4'd0, 4'd1, 4'd0, 4'd0
        );
        wait_response();
        check(resp_error === 1'b1,
              "Wrong destination produces an error");
        check(resp_rdata === 32'd0,
              "Wrong destination returns zero data");
        check(resp_dest_x === 4'd0 && resp_dest_y === 4'd0,
              "Wrong destination coordinates preserved in response");
        consume_response();

        // Misaligned word load must return the memory error.
        send_request(
            1'b0, 3'b010, 32'd17, 32'd0,
            4'd0, 4'd0, 4'd1, 4'd0
        );
        wait_response();
        check(resp_error === 1'b1,
              "Misaligned load error returned to requester");
        consume_response();

        // Verify response is held until the receiver accepts it.
        send_request(
            1'b0, 3'b010, 32'd16, 32'd0,
            4'd1, 4'd1, 4'd1, 4'd0
        );
        wait_response();

        repeat (4) begin
            @(negedge clk);
            check(resp_valid === 1'b1,
                  "Response remains valid during backpressure");
            check(resp_rdata === 32'h1234ABCD,
                  "Response data remains stable during backpressure");
        end

        check(resp_src_x === 4'd1 && resp_src_y === 4'd1,
              "Response source coordinates remain correct");
        consume_response();
        check(resp_valid === 1'b0,
              "Response clears after handshake");

        repeat (2) @(negedge clk);

        $display("");
        $display("========================================");
        if (failures == 0)
            $display("ALL MEMORY SERVICE TESTS PASSED");
        else
            $display("MEMORY SERVICE TESTS FAILED");

        $display("Total checks: %0d", checks);
        $display("Failures: %0d", failures);
        $display("========================================");

        $finish;
    end

    initial begin
        #10000;
        $display("FATAL: Testbench timeout");
        $finish;
    end

endmodule
