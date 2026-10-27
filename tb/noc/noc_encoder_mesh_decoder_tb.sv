
`timescale 1ns/1ps

module noc_encoder_mesh_decoder_tb;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    // Encoder transaction interface
    logic txn_valid;
    wire txn_ready;
    logic [3:0] dest_x;
    logic [3:0] dest_y;
    logic [3:0] src_x;
    logic [3:0] src_y;
    logic txn_write;
    logic [2:0] txn_funct3;
    logic [31:0] txn_addr;
    logic [31:0] txn_wdata;

    wire enc_flit_valid;
    wire enc_flit_ready;
    wire [31:0] enc_flit_data;
    wire enc_flit_last;

    // Mesh local interfaces, indexed:
    // 0 = (0,0), 1 = (0,1), 2 = (1,0), 3 = (1,1)
    wire [31:0] mesh_out_data [0:3];
    wire mesh_out_valid [0:3];
    wire mesh_in_ready [0:3];

    wire [31:0] mesh_in_data [0:3];
    wire mesh_in_valid [0:3];
    wire mesh_out_ready [0:3];

    // Destination decoder outputs
    wire [3:0] req_valid_bus;
    logic [3:0] req_ready_bus;
    wire [3:0] req_write_bus;
    wire [2:0] req_funct3_bus [0:3];
    wire [31:0] req_addr_bus [0:3];
    wire [31:0] req_wdata_bus [0:3];
    wire [3:0] req_src_x_bus [0:3];
    wire [3:0] req_src_y_bus [0:3];
    wire [3:0] req_dest_x_bus [0:3];
    wire [3:0] req_dest_y_bus [0:3];
    wire [3:0] protocol_error_bus;

    integer checks = 0;
    integer timeout_count;
    integer destination_index;
    integer i;

    always #5 clk = ~clk;

    // -----------------------------------------------------
    // REQUEST ENCODER AT SOURCE NODE (0,0)
    // -----------------------------------------------------
    noc_request_encoder encoder (
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

        .flit_valid(enc_flit_valid),
        .flit_ready(enc_flit_ready),
        .flit_data(enc_flit_data),
        .flit_last(enc_flit_last)
    );

    // -----------------------------------------------------
    // MESH INPUT CONNECTIONS
    // -----------------------------------------------------

    assign mesh_in_data[0]  = enc_flit_data;
    assign mesh_in_valid[0] = enc_flit_valid;
    assign enc_flit_ready   = mesh_in_ready[0];

    assign mesh_in_data[1]  = 32'd0;
    assign mesh_in_valid[1] = 1'b0;

    assign mesh_in_data[2]  = 32'd0;
    assign mesh_in_valid[2] = 1'b0;

    assign mesh_in_data[3]  = 32'd0;
    assign mesh_in_valid[3] = 1'b0;

    // -----------------------------------------------------
    // ACTUAL 2x2 MESH
    // -----------------------------------------------------
    noc_mesh_2x2 mesh (
        .clk(clk),
        .rst_n(rst_n),

        .local_data_in_00(mesh_in_data[0]),
        .local_valid_in_00(mesh_in_valid[0]),
        .local_ready_in_00(mesh_in_ready[0]),
        .local_data_out_00(mesh_out_data[0]),
        .local_valid_out_00(mesh_out_valid[0]),
        .local_ready_out_00(mesh_out_ready[0]),

        .local_data_in_01(mesh_in_data[1]),
        .local_valid_in_01(mesh_in_valid[1]),
        .local_ready_in_01(mesh_in_ready[1]),
        .local_data_out_01(mesh_out_data[1]),
        .local_valid_out_01(mesh_out_valid[1]),
        .local_ready_out_01(mesh_out_ready[1]),

        .local_data_in_10(mesh_in_data[2]),
        .local_valid_in_10(mesh_in_valid[2]),
        .local_ready_in_10(mesh_in_ready[2]),
        .local_data_out_10(mesh_out_data[2]),
        .local_valid_out_10(mesh_out_valid[2]),
        .local_ready_out_10(mesh_out_ready[2]),

        .local_data_in_11(mesh_in_data[3]),
        .local_valid_in_11(mesh_in_valid[3]),
        .local_ready_in_11(mesh_in_ready[3]),
        .local_data_out_11(mesh_out_data[3]),
        .local_valid_out_11(mesh_out_valid[3]),
        .local_ready_out_11(mesh_out_ready[3])
    );

    // -----------------------------------------------------
    // FOUR DESTINATION DECODERS
    // -----------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < 4; g = g + 1) begin : GEN_DECODERS

            noc_request_decoder decoder (
                .clk(clk),
                .rst_n(rst_n),

                .flit_valid(mesh_out_valid[g]),
                .flit_ready(mesh_out_ready[g]),
                .flit_data(mesh_out_data[g]),

                .req_valid(req_valid_bus[g]),
                .req_ready(req_ready_bus[g]),
                .req_write(req_write_bus[g]),
                .req_funct3(req_funct3_bus[g]),
                .req_addr(req_addr_bus[g]),
                .req_wdata(req_wdata_bus[g]),
                .req_src_x(req_src_x_bus[g]),
                .req_src_y(req_src_y_bus[g]),
                .req_dest_x(req_dest_x_bus[g]),
                .req_dest_y(req_dest_y_bus[g]),

                .protocol_error(protocol_error_bus[g])
            );

        end
    endgenerate

    // -----------------------------------------------------
    // TEST UTILITIES
    // -----------------------------------------------------

    task automatic check(
        input logic condition,
        input string message
    );
        begin
            checks = checks + 1;

            if (condition !== 1'b1) begin
                $display("FAIL [%0d]: %s", checks, message);
                $display("Time=%0t", $time);
                $display("Destination index=%0d", destination_index);
                $display("Encoder flit=%08h", enc_flit_data);
                $display("Request valid bus=%b", req_valid_bus);
                $display("Protocol error bus=%b", protocol_error_bus);
                $fatal(1, "END-TO-END TEST FAILED");
            end

            $display("PASS [%0d]: %s", checks, message);
        end
    endtask

    task automatic send_transaction(
        input logic [3:0] dx,
        input logic [3:0] dy,
        input logic wr,
        input logic [2:0] funct,
        input logic [31:0] addr,
        input logic [31:0] data
    );
        begin
            @(negedge clk);

            dest_x      = dx;
            dest_y      = dy;
            txn_write   = wr;
            txn_funct3  = funct;
            txn_addr    = addr;
            txn_wdata   = data;
            txn_valid   = 1'b1;

            timeout_count = 0;

            while (txn_ready !== 1'b1) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;

                if (timeout_count > 100)
                    $fatal(1, "Encoder request-ready timeout");
            end

            @(posedge clk);
            @(negedge clk);
            txn_valid = 1'b0;
        end
    endtask

    task automatic wait_for_destination(
        input integer idx
    );
        begin
            timeout_count = 0;

            while (req_valid_bus[idx] !== 1'b1) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;

                if (timeout_count > 300) begin
                    $display(
                        "Timed out waiting for destination node %0d",
                        idx
                    );
                    $fatal(1, "NoC transaction did not arrive");
                end
            end
        end
    endtask

    task automatic check_destination_request(
        input integer idx,
        input logic wr,
        input logic [2:0] funct,
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0] expected_sx,
        input logic [3:0] expected_sy,
        input logic [3:0] expected_dx,
        input logic [3:0] expected_dy
    );
        integer n;
        begin
            check(req_valid_bus[idx],
                  "Destination decoder produced a request");

            check(req_write_bus[idx] === wr,
                  "Operation type reconstructed");

            check(req_funct3_bus[idx] === funct,
                  "funct3 reconstructed");

            check(req_addr_bus[idx] === addr,
                  "Address reconstructed exactly");

            check(req_wdata_bus[idx] === data,
                  "Write data reconstructed exactly");

            check(req_src_x_bus[idx] === expected_sx,
                  "Source X reconstructed");

            check(req_src_y_bus[idx] === expected_sy,
                  "Source Y reconstructed");

            check(req_dest_x_bus[idx] === expected_dx,
                  "Destination X reconstructed");

            check(req_dest_y_bus[idx] === expected_dy,
                  "Destination Y reconstructed");

            for (n = 0; n < 4; n = n + 1) begin
                if (n != idx)
                    check(!req_valid_bus[n],
                          "No request emitted at an unintended node");
            end
        end
    endtask

    task automatic accept_destination_request(
        input integer idx
    );
        begin
            @(negedge clk);
            req_ready_bus[idx] = 1'b1;

            @(posedge clk);
            @(negedge clk);
            req_ready_bus[idx] = 1'b0;

            check(!req_valid_bus[idx],
                  "Destination request accepted");

            check(protocol_error_bus == 4'b0000,
                  "No decoder reported a protocol error");
        end
    endtask

    // -----------------------------------------------------
    // MAIN TEST SEQUENCE
    // -----------------------------------------------------

    initial begin
        txn_valid    = 1'b0;
        dest_x       = 4'd0;
        dest_y       = 4'd0;
        src_x        = 4'd0;
        src_y        = 4'd0;
        txn_write    = 1'b0;
        txn_funct3   = 3'd0;
        txn_addr     = 32'd0;
        txn_wdata    = 32'd0;
        req_ready_bus = 4'b0000;
        destination_index = 0;

        $display("");
        $display("==============================================");
        $display("ENCODER -> 2x2 NoC MESH -> FOUR DECODERS");
        $display("==============================================");

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        check(enc_flit_ready,
              "Encoder can inject into the mesh");

        check(req_valid_bus == 4'b0000,
              "No requests after reset");

        // -------------------------------------------------
        // TEST 1: DESTINATION (0,0)
        // Local delivery
        // -------------------------------------------------
        $display("\nTEST 1: Destination (0,0)");
        destination_index = 0;

        send_transaction(
            4'd0, 4'd0,
            1'b1, 3'b010,
            32'h00000100, 32'hAABBCCDD
        );

        wait_for_destination(0);

        check_destination_request(
            0, 1'b1, 3'b010,
            32'h00000100, 32'hAABBCCDD,
            4'd0, 4'd0, 4'd0, 4'd0
        );

        accept_destination_request(0);

        // -------------------------------------------------
        // TEST 2: DESTINATION (0,1)
        // One-hop vertical delivery
        // -------------------------------------------------
        $display("\nTEST 2: Destination (0,1)");
        destination_index = 1;

        send_transaction(
            4'd0, 4'd1,
            1'b1, 3'b000,
            32'h00000204, 32'h12345678
        );

        wait_for_destination(1);

        check_destination_request(
            1, 1'b1, 3'b000,
            32'h00000204, 32'h12345678,
            4'd0, 4'd0, 4'd0, 4'd1
        );

        accept_destination_request(1);

        // -------------------------------------------------
        // TEST 3: DESTINATION (1,0)
        // One-hop horizontal delivery
        // -------------------------------------------------
        $display("\nTEST 3: Destination (1,0)");
        destination_index = 2;

        send_transaction(
            4'd1, 4'd0,
            1'b0, 3'b010,
            32'h00000308, 32'h00000000
        );

        wait_for_destination(2);

        check_destination_request(
            2, 1'b0, 3'b010,
            32'h00000308, 32'h00000000,
            4'd0, 4'd0, 4'd1, 4'd0
        );

        accept_destination_request(2);

        // -------------------------------------------------
        // TEST 4: DESTINATION (1,1)
        // Two-hop delivery
        // -------------------------------------------------
        $display("\nTEST 4: Destination (1,1)");
        destination_index = 3;

        send_transaction(
            4'd1, 4'd1,
            1'b1, 3'b001,
            32'h89ABCDEF, 32'h76543210
        );

        wait_for_destination(3);

        check_destination_request(
            3, 1'b1, 3'b001,
            32'h89ABCDEF, 32'h76543210,
            4'd0, 4'd0, 4'd1, 4'd1
        );

        accept_destination_request(3);

        // -------------------------------------------------
        // TEST 5: DESTINATION BACKPRESSURE
        // -------------------------------------------------
        $display("\nTEST 5: Destination backpressure");
        destination_index = 3;

        send_transaction(
            4'd1, 4'd1,
            1'b1, 3'b010,
            32'hCAFEBABE, 32'h0BADF00D
        );

        wait_for_destination(3);

        // Keep the completed request pending.
        repeat (4) begin
            @(negedge clk);

            check(req_valid_bus[3],
                  "Request stays valid during destination stall");

            check(req_addr_bus[3] === 32'hCAFEBABE,
                  "Address stays stable during destination stall");

            check(req_wdata_bus[3] === 32'h0BADF00D,
                  "Data stays stable during destination stall");

            check(!mesh_out_ready[3],
                  "Destination decoder applies backpressure");
        end

        accept_destination_request(3);

        // -------------------------------------------------
        // TEST 6: MULTIPLE TRANSACTIONS
        // -------------------------------------------------
        $display("\nTEST 6: Repeated transactions");

        for (i = 0; i < 4; i = i + 1) begin
            destination_index = i;

            send_transaction(
                (i >= 2) ? 4'd1 : 4'd0,
                (i % 2) ? 4'd1 : 4'd0,
                i[0],
                3'b010,
                32'h50000000 + i,
                32'h60000000 + i
            );

            wait_for_destination(i);

            check_destination_request(
                i,
                i[0],
                3'b010,
                32'h50000000 + i,
                32'h60000000 + i,
                4'd0, 4'd0,
                (i >= 2) ? 4'd1 : 4'd0,
                (i % 2) ? 4'd1 : 4'd0
            );

            accept_destination_request(i);
        end

        // -------------------------------------------------
        // FINAL CHECKS
        // -------------------------------------------------
        check(req_valid_bus == 4'b0000,
              "No pending requests remain");

        check(protocol_error_bus == 4'b0000,
              "No protocol errors occurred");

        $display("");
        $display("==============================================");
        $display("ALL END-TO-END NOC TESTS PASSED");
        $display("Total checks: %0d", checks);
        $display("==============================================");

        $finish;
    end

    // Global watchdog
    initial begin
        #100000;
        $fatal(1, "WATCHDOG TIMEOUT: End-to-end NoC test");
    end

endmodule
