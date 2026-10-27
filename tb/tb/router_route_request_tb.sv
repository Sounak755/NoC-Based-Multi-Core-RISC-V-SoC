`timescale 1ns/1ps

module router_route_request_tb;

    logic [3:0] current_x, current_y;
    logic [31:0] packet_data;
    logic packet_valid;

    logic [2:0] requested_output;
    logic request_valid;

    localparam logic [2:0] LOCAL = 3'd0;
    localparam logic [2:0] NORTH = 3'd1;
    localparam logic [2:0] SOUTH = 3'd2;
    localparam logic [2:0] EAST  = 3'd3;
    localparam logic [2:0] WEST  = 3'd4;

    router_route_request dut (
        .current_x(current_x),
        .current_y(current_y),
        .packet_data(packet_data),
        .packet_valid(packet_valid),
        .requested_output(requested_output),
        .request_valid(request_valid)
    );

    task automatic check_route(
        input logic [31:0] test_packet,
        input logic [2:0] expected_direction,
        input string test_name
    );
        begin
            packet_data = test_packet;
            packet_valid = 1'b1;
            #10;

            if (request_valid &&
                requested_output == expected_direction)
                $display("PASS: %s", test_name);
            else
                $fatal(1, "FAIL: %s", test_name);
        end
    endtask

    initial begin
        current_x = 4'd1;
        current_y = 4'd1;
        packet_valid = 1'b0;
        packet_data = '0;
        #10;

        if (!request_valid)
            $display("PASS: No request for invalid packet");
        else
            $fatal(1, "FAIL: Invalid packet generated a request");

        check_route(32'h2100_0001, EAST,  "Route EAST");
        check_route(32'h0100_0002, WEST,  "Route WEST");
        check_route(32'h1200_0003, NORTH, "Route NORTH");
        check_route(32'h1000_0004, SOUTH, "Route SOUTH");
        check_route(32'h1100_0005, LOCAL, "Route LOCAL");

        $display("ALL ROUTE REQUEST TESTS PASSED");
        $finish;
    end

endmodule