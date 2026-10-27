
`timescale 1ns/1ps

module xy_router #(
    parameter int COORD_WIDTH = 2
) (
    input  logic [COORD_WIDTH-1:0] current_x,
    input  logic [COORD_WIDTH-1:0] current_y,

    input  logic [COORD_WIDTH-1:0] dest_x,
    input  logic [COORD_WIDTH-1:0] dest_y,

    output logic [2:0] direction
);

    // Direction encoding
    localparam logic [2:0] LOCAL = 3'd0;
    localparam logic [2:0] NORTH = 3'd1;
    localparam logic [2:0] SOUTH = 3'd2;
    localparam logic [2:0] EAST  = 3'd3;
    localparam logic [2:0] WEST  = 3'd4;

    always_comb begin
        // Default: packet stays at this router.
        direction = LOCAL;

        // XY routing: finish the X dimension first.
        if (dest_x > current_x)
            direction = EAST;
        else if (dest_x < current_x)
            direction = WEST;

        // Once X matches, route along Y.
        else if (dest_y > current_y)
            direction = NORTH;
        else if (dest_y < current_y)
            direction = SOUTH;
    end

endmodule
