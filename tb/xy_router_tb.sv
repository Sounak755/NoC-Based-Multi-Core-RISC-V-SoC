`timescale 1ns/1ps

module xy_router_tb;

    localparam int CW = 2;

    localparam logic [2:0] LOCAL = 3'd0;
    localparam logic [2:0] NORTH = 3'd1;
    localparam logic [2:0] SOUTH = 3'd2;
    localparam logic [2:0] EAST  = 3'd3;
    localparam logic [2:0] WEST  = 3'd4;

    logic [CW-1:0] current_x, current_y;
    logic [CW-1:0] dest_x, dest_y;
    logic [2:0] direction;

    xy_router #(.COORD_WIDTH(CW)) dut (
        .current_x(current_x),
        .current_y(current_y),
        .dest_x(dest_x),
        .dest_y(dest_y),
        .direction(direction)
    );

    task automatic check_route(
        input logic [CW-1:0] cx,
        input logic [CW-1:0] cy,
        input logic [CW-1:0] dx,
        input logic [CW-1:0] dy,
        input logic [2:0] expected,
        input string test_name
    );
        begin
            current_x = cx;
            current_y = cy;
            dest_x = dx;
            dest_y = dy;
            #1;

            if (direction !== expected)
                $fatal(1,
                    "FAIL: %s expected %0d, got %0d",
                    test_name, expected, direction);

            $display("PASS: %s", test_name);
        end
    endtask

    initial begin
        $dumpfile("sim/xy_router.vcd");
        $dumpvars(0, xy_router_tb);

        check_route(0, 0, 2, 0, EAST,  "Route East");
        check_route(2, 0, 0, 0, WEST,  "Route West");
        check_route(1, 1, 1, 2, NORTH, "Route North");
        check_route(1, 2, 1, 0, SOUTH, "Route South");
        check_route(2, 2, 2, 2, LOCAL, "Destination reached");

        check_route(0, 0, 2, 2, EAST,
                    "X direction has priority");

        $display("ALL XY ROUTER TESTS PASSED");
        $finish;
    end

endmodule