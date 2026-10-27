
`timescale 1ns/1ps

module noc_router_contention_tb;

    localparam integer DATA_WIDTH = 32;
    localparam integer COORD_WIDTH = 4;
    localparam integer FIFO_DEPTH = 8;

    localparam logic [31:0] PACKET_LOCAL = 32'h2100_00A1;
    localparam logic [31:0] PACKET_NORTH = 32'h2100_00B2;

    logic clk;
    logic rst_n;

    logic [3:0] router_x, router_y;

    logic [31:0] local_data_in;
    logic local_valid_in;
    wire local_ready_in;

    logic [31:0] north_data_in;
    logic north_valid_in;
    wire north_ready_in;

    logic [31:0] south_data_in;
    logic south_valid_in;
    wire south_ready_in;

    logic [31:0] east_data_in;
    logic east_valid_in;
    wire east_ready_in;

    logic [31:0] west_data_in;
    logic west_valid_in;
    wire west_ready_in;

    wire [31:0] local_data_out;
    wire local_valid_out;
    logic local_ready_out;

    wire [31:0] north_data_out;
    wire north_valid_out;
    logic north_ready_out;

    wire [31:0] south_data_out;
    wire south_valid_out;
    logic south_ready_out;

    wire [31:0] east_data_out;
    wire east_valid_out;
    logic east_ready_out;

    wire [31:0] west_data_out;
    wire west_valid_out;
    logic west_ready_out;

    logic [31:0] received_packets [0:1];
    integer received_count;
    integer i;

    noc_router #(
        .DATA_WIDTH(DATA_WIDTH),
        .COORD_WIDTH(COORD_WIDTH),
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

    // 10 ns clock period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Record actual EAST output handshakes.
    always @(posedge clk) begin
        if (rst_n && east_valid_out && east_ready_out) begin
            if (received_count >= 2) begin
                $fatal(1, "Unexpected extra EAST transfer: %h",
                       east_data_out);
            end

            received_packets[received_count] = east_data_out;
            received_count = received_count + 1;

            $display("EAST transfer %0d: packet=%h",
                     received_count, east_data_out);
        end
    end

    initial begin
        rst_n = 1'b0;
        router_x = 4'd1;
        router_y = 4'd1;

        local_data_in = '0;
        local_valid_in = 1'b0;

        north_data_in = '0;
        north_valid_in = 1'b0;

        south_data_in = '0;
        south_valid_in = 1'b0;

        east_data_in = '0;
        east_valid_in = 1'b0;

        west_data_in = '0;
        west_valid_in = 1'b0;

        local_ready_out = 1'b1;
        north_ready_out = 1'b1;
        south_ready_out = 1'b1;
        east_ready_out = 1'b1;
        west_ready_out = 1'b1;

        received_count = 0;
        received_packets[0] = '0;
        received_packets[1] = '0;

        // Hold reset across clock edges.
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // Allow reset and combinational logic to settle.
        @(negedge clk);
        #1;

        $display("TEST: LOCAL and NORTH simultaneously request EAST");
        $display("DEBUG: local_ready=%b north_ready=%b rst_n=%b",
                 local_ready_in, north_ready_in, rst_n);

        if (local_ready_in !== 1'b1)
            $fatal(1, "LOCAL input not ready after reset release");

        if (north_ready_in !== 1'b1)
            $fatal(1, "NORTH input not ready after reset release");

        // Present both packets together.
        local_data_in = PACKET_LOCAL;
        local_valid_in = 1'b1;

        north_data_in = PACKET_NORTH;
        north_valid_in = 1'b1;

        #1;

        if (local_ready_in !== 1'b1 ||
            north_ready_in !== 1'b1)
            $fatal(1, "Both inputs should have FIFO capacity");

        // Both handshakes occur at this rising edge.
        @(posedge clk);
        #1;

        // Deassert valid away from the sampling edge.
        @(negedge clk);
        local_valid_in = 1'b0;
        north_valid_in = 1'b0;

        // Wait for both packets to traverse the router.
        for (i = 0; i < 20; i = i + 1)
            @(negedge clk);

        if (received_count != 2)
            $fatal(1, "Expected 2 EAST transfers, got %0d",
                   received_count);

        if (!((received_packets[0] == PACKET_LOCAL &&
               received_packets[1] == PACKET_NORTH) ||
              (received_packets[0] == PACKET_NORTH &&
               received_packets[1] == PACKET_LOCAL)))
            $fatal(1, "Packets missing, duplicated, or corrupted: %h %h",
                   received_packets[0], received_packets[1]);

        $display("PASS: Both simultaneous requests were served");
        $display("PASS: No packet was lost, duplicated, or corrupted");
        $display("ALL CONTENTION TESTS PASSED");

        $finish;
    end

    // Prevent a broken test from hanging forever.
    initial begin
        #1000;
        $fatal(1, "TIMEOUT: contention test did not finish");
    end

endmodule
