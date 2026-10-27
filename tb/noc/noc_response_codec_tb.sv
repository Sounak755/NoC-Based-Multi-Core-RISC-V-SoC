
`timescale 1ns/1ps

module noc_response_codec_tb;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic resp_in_valid;
    wire resp_in_ready;
    logic [3:0] resp_in_src_x;
    logic [3:0] resp_in_src_y;
    logic [3:0] resp_in_dest_x;
    logic [3:0] resp_in_dest_y;
    logic [31:0] resp_in_data;
    logic resp_in_error;

    wire flit_valid;
    wire flit_ready;
    wire [31:0] flit_data;
    wire flit_last;

    wire resp_out_valid;
    logic resp_out_ready;
    wire [31:0] resp_out_data;
    wire resp_out_error;
    wire [3:0] resp_out_src_x;
    wire [3:0] resp_out_src_y;
    wire [3:0] resp_out_dest_x;
    wire [3:0] resp_out_dest_y;
    wire protocol_error;

    integer checks = 0;
    integer failures = 0;
    integer timeout_count;
    integer i;

    always #5 clk = ~clk;

    noc_response_encoder encoder (
        .clk(clk),
        .rst_n(rst_n),
        .resp_valid(resp_in_valid),
        .resp_ready(resp_in_ready),
        .resp_src_x(resp_in_src_x),
        .resp_src_y(resp_in_src_y),
        .resp_dest_x(resp_in_dest_x),
        .resp_dest_y(resp_in_dest_y),
        .resp_rdata(resp_in_data),
        .resp_error(resp_in_error),
        .flit_valid(flit_valid),
        .flit_ready(flit_ready),
        .flit_data(flit_data),
        .flit_last(flit_last)
    );

    noc_response_decoder decoder (
        .clk(clk),
        .rst_n(rst_n),
        .flit_valid(flit_valid),
        .flit_ready(flit_ready),
        .flit_data(flit_data),
        .resp_valid(resp_out_valid),
        .resp_ready(resp_out_ready),
        .resp_rdata(resp_out_data),
        .resp_error(resp_out_error),
        .resp_src_x(resp_out_src_x),
        .resp_src_y(resp_out_src_y),
        .resp_dest_x(resp_out_dest_x),
        .resp_dest_y(resp_out_dest_y),
        .protocol_error(protocol_error)
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
                $display("Flit=%08h", flit_data);
                $display("Response valid=%b", resp_out_valid);
                $display("Protocol error=%b", protocol_error);
            end else begin
                $display("PASS [%0d]: %s", checks, message);
            end
        end
    endtask

    task automatic send_response(
        input logic [3:0] sx,
        input logic [3:0] sy,
        input logic [3:0] dx,
        input logic [3:0] dy,
        input logic [31:0] data,
        input logic err
    );
        begin
            @(negedge clk);

            resp_in_src_x = sx;
            resp_in_src_y = sy;
            resp_in_dest_x = dx;
            resp_in_dest_y = dy;
            resp_in_data = data;
            resp_in_error = err;
            resp_in_valid = 1'b1;

            timeout_count = 0;

            while (resp_in_ready !== 1'b1 &&
                   timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            check(resp_in_ready === 1'b1,
                  "Encoder accepts response");

            if (resp_in_ready !== 1'b1)
                $fatal(1, "Response encoder ready timeout");

            @(posedge clk);
            @(negedge clk);
            resp_in_valid = 1'b0;
        end
    endtask

    task automatic wait_for_response;
        begin
            timeout_count = 0;

            while (resp_out_valid !== 1'b1 &&
                   timeout_count < 200) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            check(resp_out_valid === 1'b1,
                  "Decoder reconstructs complete response");

            if (resp_out_valid !== 1'b1)
                $fatal(1, "Response decoder timeout");
        end
    endtask

    task automatic check_response(
        input logic [31:0] expected_data,
        input logic expected_error,
        input logic [3:0] expected_sx,
        input logic [3:0] expected_sy,
        input logic [3:0] expected_dx,
        input logic [3:0] expected_dy
    );
        begin
            check(resp_out_data === expected_data,
                  "Read data reconstructed exactly");

            check(resp_out_error === expected_error,
                  "Error flag reconstructed");

            check(resp_out_src_x === expected_sx &&
                  resp_out_src_y === expected_sy,
                  "Response source coordinates reconstructed");

            check(resp_out_dest_x === expected_dx &&
                  resp_out_dest_y === expected_dy,
                  "Response destination coordinates reconstructed");

            check(protocol_error === 1'b0,
                  "No protocol error");
        end
    endtask

    task automatic consume_response;
        begin
            @(negedge clk);
            resp_out_ready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            resp_out_ready = 1'b0;

            check(resp_out_valid === 1'b0,
                  "Response clears after handshake");
        end
    endtask

    initial begin
        resp_in_valid = 1'b0;
        resp_in_src_x = 4'd0;
        resp_in_src_y = 4'd0;
        resp_in_dest_x = 4'd0;
        resp_in_dest_y = 4'd0;
        resp_in_data = 32'd0;
        resp_in_error = 1'b0;
        resp_out_ready = 1'b0;

        $display("");
        $display("==============================================");
        $display("NOC RESPONSE ENCODER / DECODER TEST");
        $display("==============================================");

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        check(resp_in_ready === 1'b1,
              "Encoder ready after reset");

        check(resp_out_valid === 1'b0,
              "No response after reset");

        // Test 1: Full-width data, response from (1,1) to (0,0).
        $display("\nTEST 1: Full-width response");

        send_response(
            4'd1, 4'd1,
            4'd0, 4'd0,
            32'hDEADBEEF,
            1'b0
        );

        wait_for_response();

        check_response(
            32'hDEADBEEF, 1'b0,
            4'd1, 4'd1, 4'd0, 4'd0
        );

        consume_response();

        // Test 2: Zero data.
        $display("\nTEST 2: Zero data");

        send_response(
            4'd0, 4'd0,
            4'd1, 4'd0,
            32'h00000000,
            1'b0
        );

        wait_for_response();

        check_response(
            32'h00000000, 1'b0,
            4'd0, 4'd0, 4'd1, 4'd0
        );

        consume_response();

        // Test 3: Error response.
        $display("\nTEST 3: Error response");

        send_response(
            4'd0, 4'd1,
            4'd1, 4'd1,
            32'h12345678,
            1'b1
        );

        wait_for_response();

        check_response(
            32'h12345678, 1'b1,
            4'd0, 4'd1, 4'd1, 4'd1
        );

        consume_response();

        // Test 4: Hold output while the receiver is stalled.
        $display("\nTEST 4: Output backpressure");

        send_response(
            4'd1, 4'd0,
            4'd0, 4'd1,
            32'hCAFEBABE,
            1'b0
        );

        wait_for_response();

        repeat (4) begin
            @(negedge clk);

            check(resp_out_valid === 1'b1,
                  "Response remains valid during stall");

            check(resp_out_data === 32'hCAFEBABE,
                  "Response data remains stable during stall");

            check(resp_out_dest_x === 4'd0 &&
                  resp_out_dest_y === 4'd1,
                  "Response coordinates remain stable during stall");
        end

        consume_response();

        // Test 5: Multiple consecutive responses.
        $display("\nTEST 5: Repeated responses");

        for (i = 0; i < 4; i = i + 1) begin
            send_response(
                (i >= 2) ? 4'd1 : 4'd0,
                (i % 2) ? 4'd1 : 4'd0,
                4'd0,
                4'd0,
                32'hABCD0000 + i,
                i[0]
            );

            wait_for_response();

            check_response(
                32'hABCD0000 + i,
                i[0],
                (i >= 2) ? 4'd1 : 4'd0,
                (i % 2) ? 4'd1 : 4'd0,
                4'd0,
                4'd0
            );

            consume_response();
        end

        check(resp_out_valid === 1'b0,
              "No response left pending");

        check(protocol_error === 1'b0,
              "No final protocol error");

        $display("");
        $display("==============================================");

        if (failures == 0)
            $display("ALL RESPONSE CODEC TESTS PASSED");
        else
            $display("RESPONSE CODEC TESTS FAILED");

        $display("Total checks: %0d", checks);
        $display("Failures: %0d", failures);
        $display("==============================================");

        if (failures != 0)
            $fatal(1, "Response codec test failed");

        $finish;
    end

    initial begin
        #50000;
        $fatal(1, "WATCHDOG TIMEOUT: Response codec test");
    end

endmodule
