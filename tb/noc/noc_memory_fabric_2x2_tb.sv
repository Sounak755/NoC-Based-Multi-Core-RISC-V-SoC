
`timescale 1ns/1ps

module noc_memory_fabric_2x2_tb;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic [3:0] txn_valid;
    logic [3:0] txn_ready;
    logic [3:0][3:0] txn_dest_x;
    logic [3:0][3:0] txn_dest_y;
    logic [3:0] txn_write;
    logic [3:0][2:0] txn_funct3;
    logic [3:0][31:0] txn_addr;
    logic [3:0][31:0] txn_wdata;

    logic [3:0] node_resp_valid;
    logic [3:0] node_resp_ready;
    logic [3:0][3:0] node_resp_src_x;
    logic [3:0][3:0] node_resp_src_y;
    logic [3:0][3:0] node_resp_dest_x;
    logic [3:0][3:0] node_resp_dest_y;
    logic [3:0][31:0] node_resp_rdata;
    logic [3:0] node_resp_error;
    logic [3:0] node_protocol_error;

    integer checks = 0;
    integer failures = 0;
    integer timeout_count;
    integer i;
    integer destination_index;

    always #5 clk = ~clk;

    noc_memory_fabric_2x2 #(
        .FIFO_DEPTH(8),
        .MEM_BYTES(256)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .source_resp_ready(4'b1111),

        .txn_valid(txn_valid),
        .txn_ready(txn_ready),
        .txn_dest_x(txn_dest_x),
        .txn_dest_y(txn_dest_y),
        .txn_write(txn_write),
        .txn_funct3(txn_funct3),
        .txn_addr(txn_addr),
        .txn_wdata(txn_wdata),

        .node_resp_valid(node_resp_valid),
        .node_resp_ready(node_resp_ready),
        .node_resp_src_x(node_resp_src_x),
        .node_resp_src_y(node_resp_src_y),
        .node_resp_dest_x(node_resp_dest_x),
        .node_resp_dest_y(node_resp_dest_y),
        .node_resp_rdata(node_resp_rdata),
        .node_resp_error(node_resp_error),

        .node_protocol_error(node_protocol_error)
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
                $display("Time=%0t", $time);
                $display("Destination index=%0d", destination_index);
                $display("Transaction ready=%b", txn_ready);
                $display("Response valid=%b", node_resp_valid);
                $display("Response error=%b", node_resp_error);
                $display("Protocol error=%b", node_protocol_error);
            end else begin
                $display("PASS [%0d]: %s", checks, message);
            end
        end
    endtask

    // Submit a transaction from source node 0, coordinate (0,0).
    task automatic send_transaction(
        input logic [3:0] dx,
        input logic [3:0] dy,
        input logic wr,
        input logic [2:0] funct,
        input logic [31:0] address,
        input logic [31:0] data
    );
        begin
            @(negedge clk);

            txn_dest_x[0] = dx;
            txn_dest_y[0] = dy;
            txn_write[0] = wr;
            txn_funct3[0] = funct;
            txn_addr[0] = address;
            txn_wdata[0] = data;
            txn_valid[0] = 1'b1;

            timeout_count = 0;

            while (txn_ready[0] !== 1'b1 &&
                   timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            check(txn_ready[0] === 1'b1,
                  "Source encoder accepts transaction");

            if (txn_ready[0] !== 1'b1)
                $fatal(1, "Source encoder request-ready timeout");

            @(posedge clk);
            @(negedge clk);
            txn_valid[0] = 1'b0;
        end
    endtask

    task automatic wait_for_response(
        input integer idx
    );
        begin
            timeout_count = 0;

            while (node_resp_valid[idx] !== 1'b1 &&
                   timeout_count < 500) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            check(node_resp_valid[idx] === 1'b1,
                  "Destination memory response received");

            if (node_resp_valid[idx] !== 1'b1) begin
                $display("Timed out waiting for node %0d", idx);
                $fatal(1, "NoC memory transaction timeout");
            end
        end
    endtask

    task automatic check_response(
        input integer idx,
        input logic [31:0] expected_data,
        input logic expected_error,
        input logic [3:0] expected_source_x,
        input logic [3:0] expected_source_y,
        input logic [3:0] expected_dest_x,
        input logic [3:0] expected_dest_y
    );
        begin
            check(node_resp_rdata[idx] === expected_data,
                  "Response data matches expected value");

            check(node_resp_error[idx] === expected_error,
                  "Response error flag is correct");

            check(node_resp_src_x[idx] === expected_source_x &&
                  node_resp_src_y[idx] === expected_source_y,
                  "Response source coordinates are correct");

            check(node_resp_dest_x[idx] === expected_dest_x &&
                  node_resp_dest_y[idx] === expected_dest_y,
                  "Response destination coordinates are correct");
        end
    endtask

    task automatic consume_response(
        input integer idx
    );
        begin
            @(negedge clk);
            node_resp_ready[idx] = 1'b1;

            @(posedge clk);
            @(negedge clk);
            node_resp_ready[idx] = 1'b0;

            check(node_resp_valid[idx] === 1'b0,
                  "Response clears after handshake");
        end
    endtask

    initial begin
        txn_valid = '0;
        txn_dest_x = '0;
        txn_dest_y = '0;
        txn_write = '0;
        txn_funct3 = '0;
        txn_addr = '0;
        txn_wdata = '0;

        node_resp_ready = '0;
        destination_index = 0;

        $display("");
        $display("================================================");
        $display("2x2 NOC MEMORY FABRIC TEST");
        $display("Source: node (0,0)");
        $display("================================================");

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        check(txn_ready[0] === 1'b1,
              "Source ready after reset");

        check(node_resp_valid === 4'b0000,
              "No responses after reset");

        check(node_protocol_error === 4'b0000,
              "No protocol errors after reset");

        // Index mapping in this fabric:
        // 0 = (0,0), 1 = (1,0), 2 = (0,1), 3 = (1,1).

        // Write distinct data to all four node-local memories.
        for (i = 0; i < 4; i = i + 1) begin
            destination_index = i;

            $display("");
            $display("WRITE TEST: destination node %0d", i);

            send_transaction(
                (i == 1 || i == 3) ? 4'd1 : 4'd0,
                (i == 2 || i == 3) ? 4'd1 : 4'd0,
                1'b1,
                3'b010,
                32'd16,
                32'hA5000000 + i
            );

            wait_for_response(i);

            check_response(
                i,
                32'd0,
                1'b0,
                4'd0,
                4'd0,
                (i == 1 || i == 3) ? 4'd1 : 4'd0,
                (i == 2 || i == 3) ? 4'd1 : 4'd0
            );

            check(node_protocol_error === 4'b0000,
                  "No protocol error during write");

            consume_response(i);
        end

        // Read each node's memory back and verify its own value.
        for (i = 0; i < 4; i = i + 1) begin
            destination_index = i;

            $display("");
            $display("READ TEST: destination node %0d", i);

            send_transaction(
                (i == 1 || i == 3) ? 4'd1 : 4'd0,
                (i == 2 || i == 3) ? 4'd1 : 4'd0,
                1'b0,
                3'b010,
                32'd16,
                32'd0
            );

            wait_for_response(i);

            check_response(
                i,
                32'hA5000000 + i,
                1'b0,
                4'd0,
                4'd0,
                (i == 1 || i == 3) ? 4'd1 : 4'd0,
                (i == 2 || i == 3) ? 4'd1 : 4'd0
            );

            check(node_protocol_error === 4'b0000,
                  "No protocol error during read");

            consume_response(i);
        end

        check(node_resp_valid === 4'b0000,
              "No responses left pending");

        check(node_protocol_error === 4'b0000,
              "No protocol errors in final state");

        $display("");
        $display("================================================");
        if (failures == 0)
            $display("ALL NOC MEMORY FABRIC TESTS PASSED");
        else
            $display("NOC MEMORY FABRIC TESTS FAILED");

        $display("Total checks: %0d", checks);
        $display("Failures: %0d", failures);
        $display("================================================");

        if (failures != 0)
            $fatal(1, "Memory fabric test failed");

        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "WATCHDOG TIMEOUT: Memory fabric test");
    end

endmodule
