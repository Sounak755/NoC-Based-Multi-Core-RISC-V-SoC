
`timescale 1ns/1ps

module noc_router_backpressure_tb;

    localparam DATA_WIDTH = 32;
    localparam COORD_WIDTH = 4;
    localparam FIFO_DEPTH = 8;

    reg clk;
    reg rst_n;
    reg [COORD_WIDTH-1:0] router_x, router_y;

    reg [DATA_WIDTH-1:0] local_data_in;
    reg local_valid_in;
    wire local_ready_in;

    reg [DATA_WIDTH-1:0] north_data_in, south_data_in;
    reg [DATA_WIDTH-1:0] east_data_in, west_data_in;
    reg north_valid_in, south_valid_in, east_valid_in, west_valid_in;
    wire north_ready_in, south_ready_in, east_ready_in, west_ready_in;

    wire [DATA_WIDTH-1:0] local_data_out;
    wire [DATA_WIDTH-1:0] north_data_out, south_data_out;
    wire [DATA_WIDTH-1:0] east_data_out, west_data_out;
    wire local_valid_out, north_valid_out, south_valid_out;
    wire east_valid_out, west_valid_out;

    reg local_ready_out, north_ready_out, south_ready_out;
    reg east_ready_out, west_ready_out;

    localparam [DATA_WIDTH-1:0] PACKET = 32'h2100_00AB;

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

    always #5 clk = ~clk;

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
        west_ready_out = 1;

        // Block the EAST output.
        east_ready_out = 0;

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        $display("TEST: EAST output is blocked");

        // Inject a packet whose destination is (2,1).
        @(negedge clk);
        local_data_in = PACKET;
        local_valid_in = 1;

        // Wait until the router accepts the input packet.
        while (local_ready_in !== 1'b1)
            @(negedge clk);

        @(posedge clk);
        @(negedge clk);
        local_valid_in = 0;

        // Wait for the packet to reach the EAST output.
        fork : wait_for_east
            begin
                wait (east_valid_out === 1'b1);
            end
            begin
                repeat (20) @(posedge clk);
                $fatal(1, "Timeout: packet never reached EAST output");
            end
        join_any
        disable wait_for_east;

        if (east_data_out !== PACKET)
            $fatal(1, "Wrong EAST packet: got %h expected %h",
                   east_data_out, PACKET);

        $display("PASS: Packet reached EAST output while blocked");

        // Keep the output blocked for three clock cycles.
        repeat (3) begin
            @(posedge clk);
            #1;

            if (east_valid_out !== 1'b1)
                $fatal(1, "EAST valid dropped while output was blocked");

            if (east_data_out !== PACKET)
                $fatal(1, "EAST data changed while output was blocked");
        end

        $display("PASS: EAST valid and data stayed stable under backpressure");

        // Allow the downstream receiver to accept the packet.
        @(negedge clk);
        east_ready_out = 1;

        @(posedge clk);
        #1;

        if (east_valid_out !== 1'b0)
            $fatal(1, "EAST output did not clear after packet transfer");

        $display("PASS: Packet transferred after EAST became ready");
        $display("ALL BACKPRESSURE TESTS PASSED");

        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Global testbench timeout");
    end

endmodule
