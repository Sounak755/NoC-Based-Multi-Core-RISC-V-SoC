
`timescale 1ns/1ps

module noc_router_tb;

    localparam integer DATA_WIDTH = 32;
    localparam integer COORD_WIDTH = 4;
    localparam integer FIFO_DEPTH = 8;

    localparam [2:0] LOCAL = 3'd0;
    localparam [2:0] NORTH = 3'd1;
    localparam [2:0] SOUTH = 3'd2;
    localparam [2:0] EAST  = 3'd3;
    localparam [2:0] WEST  = 3'd4;

    reg clk;
    reg rst_n;

    reg [COORD_WIDTH-1:0] router_x;
    reg [COORD_WIDTH-1:0] router_y;

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
        $dumpfile("sim/noc_router.vcd");
        $dumpvars(0, noc_router_tb);
    end

    task automatic clear_inputs;
        begin
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
            east_ready_out = 1;
            west_ready_out = 1;
        end
    endtask

    task automatic send_local(input [DATA_WIDTH-1:0] packet);
        integer timeout_count;
        begin
            timeout_count = 0;

            @(negedge clk);
            local_data_in = packet;
            local_valid_in = 1'b1;

            while ((local_ready_in !== 1'b1) &&
                   (timeout_count < 100)) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (local_ready_in !== 1'b1)
                $fatal(1, "Timeout waiting for LOCAL input ready");

            @(posedge clk);
            @(negedge clk);
            local_valid_in = 1'b0;
        end
    endtask

    task automatic check_output(
        input [2:0] direction,
        input [DATA_WIDTH-1:0] expected_packet
    );
        integer timeout_count;
        reg observed;
        reg [DATA_WIDTH-1:0] received_packet;
        begin
            timeout_count = 0;
            observed = 0;
            received_packet = 0;

            while ((timeout_count < 100) && !observed) begin
                @(negedge clk);

                case (direction)
                    NORTH: begin
                        observed = north_valid_out;
                        received_packet = north_data_out;
                    end
                    SOUTH: begin
                        observed = south_valid_out;
                        received_packet = south_data_out;
                    end
                    EAST: begin
                        observed = east_valid_out;
                        received_packet = east_data_out;
                    end
                    WEST: begin
                        observed = west_valid_out;
                        received_packet = west_data_out;
                    end
                    LOCAL: begin
                        observed = local_valid_out;
                        received_packet = local_data_out;
                    end
                    default: observed = 0;
                endcase

                timeout_count = timeout_count + 1;
            end

            if (!observed)
                $fatal(1, "Timeout waiting for output direction %0d",
                       direction);

            if (received_packet !== expected_packet)
                $fatal(1,
                    "Data mismatch on direction %0d: got %h expected %h",
                    direction, received_packet, expected_packet);

            $display("PASS: direction=%0d packet=%h",
                     direction, received_packet);

            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task automatic test_route(
        input [2:0] direction,
        input [DATA_WIDTH-1:0] packet
    );
        begin
            fork
                send_local(packet);
                check_output(direction, packet);
            join
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        router_x = 1;
        router_y = 1;

        clear_inputs();

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        $display("PASS TEST 1: Reset complete; router at (1,1)");

        // Destination X = packet[31:28]
        // Destination Y = packet[27:24]

        test_route(EAST,  32'h2100_0001);
        test_route(NORTH, 32'h1200_0002);
        test_route(SOUTH, 32'h1000_0003);
        test_route(WEST,  32'h0100_0004);
        test_route(LOCAL, 32'h1100_0005);

        $display("ALL NOC ROUTER TESTS PASSED");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Global testbench timeout");
    end

endmodule
