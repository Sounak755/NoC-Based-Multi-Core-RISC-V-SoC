
`timescale 1ns/1ps

module noc_router_fifo_capacity_tb;

    localparam integer DATA_WIDTH = 32;
    localparam integer FIFO_DEPTH = 8;
    localparam integer TOTAL_PACKETS = FIFO_DEPTH + 1;

    reg clk;
    reg rst_n;

    reg [3:0] router_x;
    reg [3:0] router_y;

    reg [DATA_WIDTH-1:0] local_data_in;
    reg local_valid_in;
    wire local_ready_in;

    reg [DATA_WIDTH-1:0] north_data_in;
    reg north_valid_in;
    wire north_ready_in;

    reg [DATA_WIDTH-1:0] south_data_in;
    reg south_valid_in;
    wire south_ready_in;

    reg [DATA_WIDTH-1:0] east_data_in;
    reg east_valid_in;
    wire east_ready_in;

    reg [DATA_WIDTH-1:0] west_data_in;
    reg west_valid_in;
    wire west_ready_in;

    wire [DATA_WIDTH-1:0] local_data_out;
    wire local_valid_out;
    reg local_ready_out;

    wire [DATA_WIDTH-1:0] north_data_out;
    wire north_valid_out;
    reg north_ready_out;

    wire [DATA_WIDTH-1:0] south_data_out;
    wire south_valid_out;
    reg south_ready_out;

    wire [DATA_WIDTH-1:0] east_data_out;
    wire east_valid_out;
    reg east_ready_out;

    wire [DATA_WIDTH-1:0] west_data_out;
    wire west_valid_out;
    reg west_ready_out;

    integer received_count;
    integer i;

    reg [DATA_WIDTH-1:0] expected_data;

    noc_router #(
        .DATA_WIDTH(DATA_WIDTH),
        .COORD_WIDTH(4),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .router_x(router_x),
        .router_y(router_y),

        .local_data_in(local_data_in),
        .local_valid_in(local_valid_in),
        .local_ready_in(local_ready_in),

        .north_data_in(north_data_in),
        .north_valid_in(north_valid_in),
        .north_ready_in(north_ready_in),

        .south_data_in(south_data_in),
        .south_valid_in(south_valid_in),
        .south_ready_in(south_ready_in),

        .east_data_in(east_data_in),
        .east_valid_in(east_valid_in),
        .east_ready_in(east_ready_in),

        .west_data_in(west_data_in),
        .west_valid_in(west_valid_in),
        .west_ready_in(west_ready_in),

        .local_data_out(local_data_out),
        .local_valid_out(local_valid_out),
        .local_ready_out(local_ready_out),

        .north_data_out(north_data_out),
        .north_valid_out(north_valid_out),
        .north_ready_out(north_ready_out),

        .south_data_out(south_data_out),
        .south_valid_out(south_valid_out),
        .south_ready_out(south_ready_out),

        .east_data_out(east_data_out),
        .east_valid_out(east_valid_out),
        .east_ready_out(east_ready_out),

        .west_data_out(west_data_out),
        .west_valid_out(west_valid_out),
        .west_ready_out(west_ready_out)
    );

    always #5 clk = ~clk;

    // Count only actual EAST output handshakes.
    always @(posedge clk) begin
        if (rst_n && east_valid_out && east_ready_out) begin
            expected_data = 32'h2100_0001 + received_count;

            if (east_data_out !== expected_data) begin
                $display("FAIL: Expected %h, received %h",
                         expected_data, east_data_out);
                $fatal(1, "Packet order or duplication error");
            end

            received_count = received_count + 1;
            $display("EAST received packet %0d: %h",
                     received_count, east_data_out);
        end
    end

    initial begin
        clk = 0;
        rst_n = 0;

        router_x = 1;
        router_y = 1;

        local_data_in = 0;
        local_valid_in = 0;

        north_data_in = 0;
        north_valid_in = 0;

        south_data_in = 0;
        south_valid_in = 0;

        east_data_in = 0;
        east_valid_in = 0;

        west_data_in = 0;
        west_valid_in = 0;

        local_ready_out = 1;
        north_ready_out = 1;
        south_ready_out = 1;

        // Block EAST so the LOCAL input FIFO fills.
        east_ready_out = 0;
        west_ready_out = 1;

        received_count = 0;
        expected_data = 0;

        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        $display("TEST 1: Fill LOCAL input FIFO while EAST is blocked");

        for (i = 1; i <= FIFO_DEPTH; i = i + 1) begin
            local_data_in = 32'h2100_0000 + i;
            local_valid_in = 1;

            // Wait for an input handshake, sampling away from the
            // active clock edge to avoid testbench/DUT races.
            while (local_ready_in !== 1'b1)
                @(negedge clk);

            @(posedge clk);
            @(negedge clk);
        end

        local_valid_in = 0;

        if (local_ready_in !== 1'b0) begin
            $fatal(1, "FIFO did not assert backpressure when full");
        end

        $display("PASS: FIFO accepted %0d packets", FIFO_DEPTH);
        $display("PASS: Backpressure asserted when FIFO became full");

        $display("TEST 2: Hold an additional packet while FIFO is full");

        local_data_in = 32'h2100_0009;
        local_valid_in = 1;

        repeat (3) @(negedge clk);

        if (local_ready_in !== 1'b0) begin
            $fatal(1, "Expected backpressure for ninth packet");
        end

        $display("PASS: Extra packet held while FIFO was full");

        $display("TEST 3: Unblock EAST and verify recovery");
        east_ready_out = 1;

        // Keep valid asserted until the ninth packet is accepted.
        // Do not add an extra posedge after observing ready.
        while (local_ready_in !== 1'b1)
            @(negedge clk);

        @(posedge clk);
        @(negedge clk);
        local_valid_in = 0;

        // Wait for exactly nine output transfers.
        while (received_count < TOTAL_PACKETS)
            @(negedge clk);

        // Allow another clock edge to expose any unexpected duplicate.
        @(posedge clk);
        @(negedge clk);

        if (received_count != TOTAL_PACKETS) begin
            $fatal(1, "Expected %0d transfers, observed %0d",
                   TOTAL_PACKETS, received_count);
        end

        if (east_valid_out !== 1'b0) begin
            $fatal(1, "Unexpected extra packet remains at EAST output");
        end

        $display("PASS: All %0d packets transferred in order",
                 TOTAL_PACKETS);
        $display("PASS: No duplicate packet detected");
        $display("ALL FIFO CAPACITY TESTS PASSED");

        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "TIMEOUT: FIFO capacity test did not complete");
    end

endmodule
