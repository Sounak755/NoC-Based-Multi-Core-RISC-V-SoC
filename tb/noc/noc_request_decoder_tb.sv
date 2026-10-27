
`timescale 1ns/1ps

module noc_request_decoder_tb;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic flit_valid;
    wire flit_ready;
    logic [31:0] flit_data;

    wire req_valid;
    logic req_ready;
    wire req_write;
    wire [2:0] req_funct3;
    wire [31:0] req_addr;
    wire [31:0] req_wdata;
    wire [3:0] req_src_x;
    wire [3:0] req_src_y;
    wire [3:0] req_dest_x;
    wire [3:0] req_dest_y;
    wire protocol_error;

    integer checks = 0;
    integer i;
    integer j;
    integer src;

    logic [77:0] payload [0:3];
    logic [7:0] destination [0:3];
    logic [7:0] source [0:3];

    logic [31:0] saved_addr;
    logic [31:0] saved_wdata;
    logic saved_write;
    logic [2:0] saved_funct3;

    always #5 clk = ~clk;

    noc_request_decoder dut (
        .clk(clk),
        .rst_n(rst_n),
        .flit_valid(flit_valid),
        .flit_ready(flit_ready),
        .flit_data(flit_data),
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
        .protocol_error(protocol_error)
    );

    function automatic [31:0] make_flit(
        input logic [7:0] dest,
        input logic [7:0] src_addr,
        input integer idx,
        input logic [77:0] p
    );
        logic [12:0] chunk;
        begin
            case (idx)
                0: chunk = p[77:65];
                1: chunk = p[64:52];
                2: chunk = p[51:39];
                3: chunk = p[38:26];
                4: chunk = p[25:13];
                5: chunk = p[12:0];
                default: chunk = 13'd0;
            endcase

            make_flit = {
                dest,
                src_addr,
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
                $display("FAIL [%0d] %s", checks, message);
                $display("time=%0t flit=%08h", $time, flit_data);
                $display("req_valid=%b protocol_error=%b",
                         req_valid, protocol_error);
                $fatal(1, "TEST FAILED");
            end
            $display("PASS [%0d] %s", checks, message);
        end
    endtask

    // Drive exactly one valid/ready transfer.
    task automatic send_flit(input logic [31:0] d);
        begin
            @(negedge clk);
            while (flit_ready !== 1'b1)
                @(negedge clk);

            flit_data  = d;
            flit_valid = 1'b1;

            @(posedge clk);
            if (!(flit_valid && flit_ready))
                $fatal(1, "Input handshake failed");

            @(negedge clk);
            flit_valid = 1'b0;
            flit_data  = 32'd0;
        end
    endtask

    task automatic clear_error_check;
        begin
            // protocol_error is a one-cycle pulse.
            @(negedge clk);
            check(!protocol_error, "Protocol error pulse clears");
        end
    endtask

    task automatic send_packet(
        input logic [7:0] dest,
        input logic [7:0] src_addr,
        input logic wr,
        input logic [2:0] funct,
        input logic [31:0] addr,
        input logic [31:0] wdata
    );
        logic [77:0] p;
        integer n;
        begin
            p = {10'b0, wr, funct, addr, wdata};

            for (n = 0; n < 6; n = n + 1)
                send_flit(make_flit(dest, src_addr, n, p));
        end
    endtask

    task automatic check_request(
        input logic wr,
        input logic [2:0] funct,
        input logic [31:0] addr,
        input logic [31:0] wdata,
        input logic [3:0] sx,
        input logic [3:0] sy,
        input logic [3:0] dx,
        input logic [3:0] dy
    );
        begin
            check(req_valid, "Request valid");
            check(req_write === wr, "Write flag");
            check(req_funct3 === funct, "funct3");
            check(req_addr === addr, "Address exact match");
            check(req_wdata === wdata, "Write data exact match");
            check(req_src_x === sx, "Source X");
            check(req_src_y === sy, "Source Y");
            check(req_dest_x === dx, "Destination X");
            check(req_dest_y === dy, "Destination Y");
        end
    endtask

    task automatic accept_request;
        begin
            @(negedge clk);
            req_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            req_ready = 1'b0;
            check(!req_valid, "Request accepted and valid cleared");
        end
    endtask

    task automatic expect_error(
        input logic [31:0] d,
        input string message
    );
        begin
            send_flit(d);
            check(protocol_error, message);
            clear_error_check();
        end
    endtask

    initial begin
        flit_valid = 1'b0;
        flit_data  = 32'd0;
        req_ready  = 1'b0;

        payload[0] = 78'd0;
        payload[1] = 78'd0;
        payload[2] = 78'd0;
        payload[3] = 78'd0;

        // -------------------------------------------------
        // TEST 1: RESET
        // -------------------------------------------------
        $display("\nTEST 1: RESET");

        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        check(flit_ready, "Ready after reset");
        check(!req_valid, "No request after reset");
        check(!protocol_error, "No error after reset");

        // -------------------------------------------------
        // TEST 2: WRITE REQUEST AND FIELD RECONSTRUCTION
        // -------------------------------------------------
        $display("\nTEST 2: WRITE REQUEST");

        send_packet(
            8'h11, 8'h00,
            1'b1, 3'b010,
            32'h12345678, 32'hDEADBEEF
        );

        check_request(
            1'b1, 3'b010,
            32'h12345678, 32'hDEADBEEF,
            4'd0, 4'd0, 4'd1, 4'd1
        );

        check(!protocol_error, "Valid packet has no error");

        // -------------------------------------------------
        // TEST 3: OUTPUT BACKPRESSURE
        // -------------------------------------------------
        $display("\nTEST 3: BACKPRESSURE");

        check(!flit_ready, "Input blocked while request pending");

        saved_addr    = req_addr;
        saved_wdata   = req_wdata;
        saved_write   = req_write;
        saved_funct3  = req_funct3;

        repeat (4) begin
            @(negedge clk);
            check(req_valid, "Request remains valid while stalled");
            check(req_addr === saved_addr, "Address remains stable");
            check(req_wdata === saved_wdata, "Data remains stable");
            check(req_write === saved_write, "Write flag remains stable");
            check(req_funct3 === saved_funct3, "funct3 remains stable");
            check(!flit_ready, "Input remains stalled");
        end

        accept_request();
        check(flit_ready, "Input resumes after acceptance");

        // -------------------------------------------------
        // TEST 4: READ REQUEST
        // -------------------------------------------------
        $display("\nTEST 4: READ REQUEST");

        send_packet(
            8'h01, 8'h10,
            1'b0, 3'b100,
            32'h87654321, 32'h00000000
        );

        check_request(
            1'b0, 3'b100,
            32'h87654321, 32'h00000000,
            4'd1, 4'd0, 4'd0, 4'd1
        );

        accept_request();

        // -------------------------------------------------
        // TEST 5: ALL FOUR SOURCES INTERLEAVED
        // -------------------------------------------------
        $display("\nTEST 5: FOUR-SOURCE INTERLEAVING");

        destination[0] = 8'h00;
        source[0]      = 8'h00;
        payload[0]     = {
            10'b0, 1'b1, 3'b000,
            32'h10000001, 32'hA0000001
        };

        destination[1] = 8'h01;
        source[1]      = 8'h01;
        payload[1]     = {
            10'b0, 1'b0, 3'b001,
            32'h20000002, 32'h00000000
        };

        destination[2] = 8'h10;
        source[2]      = 8'h10;
        payload[2]     = {
            10'b0, 1'b1, 3'b010,
            32'h30000003, 32'hB0000003
        };

        destination[3] = 8'h11;
        source[3]      = 8'h11;
        payload[3]     = {
            10'b0, 1'b0, 3'b011,
            32'h40000004, 32'h00000000
        };

        // Send flit 0 from each source.
        for (src = 0; src < 4; src = src + 1)
            send_flit(make_flit(
                destination[src], source[src], 0, payload[src]
            ));

        // Alternate all four streams for indices 1-4.
        for (i = 1; i <= 4; i = i + 1) begin
            for (src = 0; src < 4; src = src + 1) begin
                send_flit(make_flit(
                    destination[src], source[src], i, payload[src]
                ));
            end
        end

        // Finish each stream separately because the decoder
        // exposes a single completed-request output.
        for (src = 0; src < 4; src = src + 1) begin
            send_flit(make_flit(
                destination[src], source[src], 5, payload[src]
            ));

            case (src)
                0: check_request(
                    1'b1, 3'b000,
                    32'h10000001, 32'hA0000001,
                    4'd0, 4'd0, 4'd0, 4'd0
                );
                1: check_request(
                    1'b0, 3'b001,
                    32'h20000002, 32'h00000000,
                    4'd0, 4'd1, 4'd0, 4'd1
                );
                2: check_request(
                    1'b1, 3'b010,
                    32'h30000003, 32'hB0000003,
                    4'd1, 4'd0, 4'd1, 4'd0
                );
                3: check_request(
                    1'b0, 3'b011,
                    32'h40000004, 32'h00000000,
                    4'd1, 4'd1, 4'd1, 4'd1
                );
            endcase

            accept_request();
        end

        // -------------------------------------------------
        // TEST 6: MISSING FIRST FLIT
        // -------------------------------------------------
        $display("\nTEST 6: MISSING FIRST FLIT");

        expect_error(
            make_flit(8'h11, 8'h00, 1, payload[0]),
            "Index 1 without index 0 rejected"
        );

        // -------------------------------------------------
        // TEST 7: REPEATED INDEX
        // -------------------------------------------------
        $display("\nTEST 7: REPEATED INDEX");

        send_flit(make_flit(8'h11, 8'h00, 0, payload[0]));
        send_flit(make_flit(8'h11, 8'h00, 1, payload[0]));

        expect_error(
            make_flit(8'h11, 8'h00, 1, payload[0]),
            "Repeated index rejected"
        );

        check(!req_valid, "Repeated index creates no request");

        // -------------------------------------------------
        // TEST 8: SKIPPED INDEX
        // -------------------------------------------------
        $display("\nTEST 8: SKIPPED INDEX");

        send_flit(make_flit(8'h11, 8'h00, 0, payload[0]));

        expect_error(
            make_flit(8'h11, 8'h00, 2, payload[0]),
            "Skipped index rejected"
        );

        check(!req_valid, "Skipped index creates no request");

        // -------------------------------------------------
        // TEST 9: DESTINATION CHANGES MID-PACKET
        // -------------------------------------------------
        $display("\nTEST 9: DESTINATION CHANGE");

        send_flit(make_flit(8'h00, 8'h00, 0, payload[0]));

        expect_error(
            make_flit(8'h01, 8'h00, 1, payload[0]),
            "Destination change rejected"
        );

        // -------------------------------------------------
        // TEST 10: SOURCE CHANGE MID-PACKET
        // -------------------------------------------------
        $display("\nTEST 10: SOURCE CHANGE");

        send_flit(make_flit(8'h11, 8'h00, 0, payload[0]));

        // Source 01 has no active packet at index 1.
        expect_error(
            make_flit(8'h11, 8'h01, 1, payload[0]),
            "Source change cannot continue another context"
        );

        // -------------------------------------------------
        // TEST 11: INVALID INDICES 6 AND 7
        // -------------------------------------------------
        $display("\nTEST 11: INVALID INDICES");

        expect_error(
            {8'h11, 8'h00, 3'b110, 13'h0123},
            "Index 6 rejected"
        );

        expect_error(
            {8'h11, 8'h00, 3'b111, 13'h0456},
            "Index 7 rejected"
        );

        // -------------------------------------------------
        // TEST 12: INVALID SOURCE COORDINATE
        // -------------------------------------------------
        $display("\nTEST 12: INVALID SOURCE COORDINATE");

        expect_error(
            {4'd2, 4'd0, 4'd0, 4'd0, 3'd0, 13'd0},
            "Invalid destination coordinate rejected"
        );

        expect_error(
            {4'd0, 4'd0, 4'd2, 4'd0, 3'd0, 13'd0},
            "Invalid source coordinate rejected"
        );

        // -------------------------------------------------
        // TEST 13: RESET DURING PARTIAL PACKET
        // -------------------------------------------------
        $display("\nTEST 13: MID-PACKET RESET");

        send_flit(make_flit(8'h11, 8'h00, 0, payload[0]));
        send_flit(make_flit(8'h11, 8'h00, 1, payload[0]));
        send_flit(make_flit(8'h11, 8'h00, 2, payload[0]));

        @(negedge clk);
        rst_n = 1'b0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        check(!req_valid, "Reset clears request output");
        check(!protocol_error, "Reset clears error");
        check(flit_ready, "Decoder ready after reset");

        expect_error(
            make_flit(8'h11, 8'h00, 3, payload[0]),
            "Partial packet cannot continue after reset"
        );

        // -------------------------------------------------
        // TEST 14: RESTART WITH NEW INDEX 0
        // -------------------------------------------------
        $display("\nTEST 14: RESTART RECOVERY");

        // Start a packet, then restart with a fresh index 0.
        send_flit(make_flit(8'h11, 8'h00, 0, payload[0]));
        send_flit(make_flit(8'h11, 8'h00, 0, payload[2]));

        // Complete the replacement packet.
        for (i = 1; i < 6; i = i + 1)
            send_flit(make_flit(8'h11, 8'h00, i, payload[2]));

        check_request(
            1'b1, 3'b010,
            32'h30000003, 32'hB0000003,
            4'd0, 4'd0, 4'd1, 4'd1
        );

        accept_request();

        // -------------------------------------------------
        // TEST 15: BACK-TO-BACK VALID PACKETS
        // -------------------------------------------------
        $display("\nTEST 15: BACK-TO-BACK REQUESTS");

        send_packet(
            8'h00, 8'h01,
            1'b1, 3'b000,
            32'h00000010, 32'h12345678
        );

        check_request(
            1'b1, 3'b000,
            32'h00000010, 32'h12345678,
            4'd0, 4'd1, 4'd0, 4'd0
        );

        accept_request();

        send_packet(
            8'h10, 8'h11,
            1'b0, 3'b101,
            32'hFFFFFFFC, 32'h00000000
        );

        check_request(
            1'b0, 3'b101,
            32'hFFFFFFFC, 32'h00000000,
            4'd1, 4'd1, 4'd1, 4'd0
        );

        accept_request();

        // -------------------------------------------------
        // FINAL RESULT
        // -------------------------------------------------
        $display("\n==========================================");
        $display("ALL DECODER TESTS PASSED");
        $display("Total checks: %0d", checks);
        $display("==========================================");

        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "WATCHDOG TIMEOUT");
    end

endmodule
