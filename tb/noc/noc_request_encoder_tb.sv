
`timescale 1ns/1ps

module noc_request_encoder_tb;

    logic clk;
    logic rst_n;

    logic txn_valid;
    wire txn_ready;

    logic [3:0] dest_x, dest_y;
    logic [3:0] src_x, src_y;
    logic txn_write;
    logic [2:0] txn_funct3;
    logic [31:0] txn_addr, txn_wdata;

    wire flit_valid;
    logic flit_ready;
    wire [31:0] flit_data;
    wire flit_last;

    logic [77:0] expected_packet;
    logic [31:0] expected_flit;
    logic [31:0] held_flit;

    integer checks;
    integer i;

    always #5 clk = ~clk;

    noc_request_encoder dut (
        .clk(clk),
        .rst_n(rst_n),
        .txn_valid(txn_valid),
        .txn_ready(txn_ready),
        .dest_x(dest_x),
        .dest_y(dest_y),
        .src_x(src_x),
        .src_y(src_y),
        .txn_write(txn_write),
        .txn_funct3(txn_funct3),
        .txn_addr(txn_addr),
        .txn_wdata(txn_wdata),
        .flit_valid(flit_valid),
        .flit_ready(flit_ready),
        .flit_data(flit_data),
        .flit_last(flit_last)
    );

    function automatic [31:0] make_expected_flit(
        input integer idx,
        input logic [77:0] packet,
        input logic [7:0] destination,
        input logic [7:0] source
    );
        logic [12:0] chunk;
        begin
            case (idx)
                0: chunk = packet[77:65];
                1: chunk = packet[64:52];
                2: chunk = packet[51:39];
                3: chunk = packet[38:26];
                4: chunk = packet[25:13];
                5: chunk = packet[12:0];
                default: chunk = 13'd0;
            endcase

            make_expected_flit = {
                destination,
                source,
                idx[2:0],
                chunk
            };
        end
    endfunction

    task automatic check(
        input logic condition,
        input string message
    );
        begin
            checks = checks + 1;

            if (condition !== 1'b1) begin
                $display("");
                $display("FAIL [%0d]: %s", checks, message);
                $display("Time             : %0t", $time);
                $display("Observed flit    : %08h", flit_data);
                $display("Expected flit    : %08h", expected_flit);
                $display("Valid / Ready    : %b / %b",
                         flit_valid, flit_ready);
                $fatal(1, "TEST FAILED");
            end

            $display("PASS [%0d]: %s", checks, message);
        end
    endtask

    task automatic send_and_check_packet(
        input logic [7:0] destination,
        input logic [7:0] source,
        input logic write_value,
        input logic [2:0] funct3_value,
        input logic [31:0] address_value,
        input logic [31:0] write_data_value
    );
        integer k;
        begin
            // Construct the expected request independently.
            expected_packet = {
                10'b0,
                write_value,
                funct3_value,
                address_value,
                write_data_value
            };

            // Present a transaction while idle.
            @(negedge clk);
            txn_valid  = 1'b1;
            dest_x     = destination[7:4];
            dest_y     = destination[3:0];
            src_x      = source[7:4];
            src_y      = source[3:0];
            txn_write  = write_value;
            txn_funct3 = funct3_value;
            txn_addr   = address_value;
            txn_wdata  = write_data_value;

            check(txn_ready, "Encoder ready before request");

            @(posedge clk);
            @(negedge clk);
            txn_valid = 1'b0;

            check(flit_valid, "First flit valid after capture");
            check(!txn_ready, "Encoder busy after capture");

            // Hold the first flit under backpressure.
            flit_ready = 1'b0;
            held_flit = flit_data;

            repeat (2) begin
                @(negedge clk);
                check(flit_valid, "Valid held under backpressure");
                check(flit_data === held_flit,
                      "Flit data stable under backpressure");
            end

            // Consume and check every flit.
            flit_ready = 1'b1;

            for (k = 0; k < 6; k = k + 1) begin
                expected_flit = make_expected_flit(
                    k,
                    expected_packet,
                    destination,
                    source
                );

                check(flit_valid, "Flit valid during transmission");
                check(flit_data === expected_flit,
                      "Entire flit matches expected value");
                check(flit_data[31:24] === destination,
                      "Destination preserved for router");
                check(flit_data[23:16] === source,
                      "Source coordinates preserved");
                check(flit_data[15:13] === k[2:0],
                      "Sequence index is correct");
                check(flit_data[12:0] === expected_flit[12:0],
                      "Payload chunk is correct");
                check(flit_last === (k == 5),
                      "Final-flit indicator is correct");

                @(posedge clk);
                @(negedge clk);
            end

            flit_ready = 1'b0;

            check(!flit_valid, "Encoder returns to idle");
            check(!flit_last, "Last flag clears after packet");
            check(txn_ready, "Encoder accepts a new request");
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;

        txn_valid  = 1'b0;
        dest_x     = 4'd0;
        dest_y     = 4'd0;
        src_x      = 4'd0;
        src_y      = 4'd0;
        txn_write  = 1'b0;
        txn_funct3 = 3'd0;
        txn_addr   = 32'd0;
        txn_wdata  = 32'd0;

        flit_ready = 1'b0;

        expected_packet = 78'd0;
        expected_flit   = 32'd0;
        held_flit       = 32'd0;
        checks          = 0;
        i               = 0;

        // ==================================================
        // TEST 1: RESET
        // ==================================================
        $display("");
        $display("TEST 1: Reset");

        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        check(txn_ready, "Ready asserted after reset");
        check(!flit_valid, "No valid flit while idle");
        check(flit_data === 32'd0, "Idle data output is zero");

        // ==================================================
        // TEST 2: WRITE REQUEST TO NODE (1,1)
        // ==================================================
        $display("");
        $display("TEST 2: Write request and six-flit encoding");

        send_and_check_packet(
            8'h11,
            8'h00,
            1'b1,
            3'b010,
            32'h12345678,
            32'hDEADBEEF
        );

        // ==================================================
        // TEST 3: READ REQUEST TO NODE (0,1)
        // ==================================================
        $display("");
        $display("TEST 3: Read request with different fields");

        send_and_check_packet(
            8'h01,
            8'h10,
            1'b0,
            3'b010,
            32'h00000124,
            32'h00000000
        );

        // ==================================================
        // TEST 4: SECOND WRITE WITH BYTE ACCESS
        // ==================================================
        $display("");
        $display("TEST 4: Byte write request");

        send_and_check_packet(
            8'h10,
            8'h01,
            1'b1,
            3'b000,
            32'h00000043,
            32'h000000A5
        );

        // ==================================================
        // TEST 5: RESET RECOVERY
        // ==================================================
        $display("");
        $display("TEST 5: Reset recovery");

        @(negedge clk);
        rst_n = 1'b0;
        flit_ready = 1'b0;
        txn_valid = 1'b0;

        @(negedge clk);

        check(!txn_ready, "Ready low during reset");
        check(!flit_valid, "Valid low during reset");

        @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);

        check(txn_ready, "Encoder ready after reset recovery");
        check(!flit_valid, "No stale flit after reset recovery");

        // ==================================================
        // FINAL RESULT
        // ==================================================
        $display("");
        $display("==============================================");
        $display("ALL REQUEST ENCODER TESTS PASSED");
        $display("Total checks: %0d", checks);
        $display("==============================================");

        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "TIMEOUT: Request encoder testbench");
    end

endmodule
