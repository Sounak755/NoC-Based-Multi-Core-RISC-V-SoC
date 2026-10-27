`timescale 1ns/1ps

module router_route_request #(
    parameter int COORD_WIDTH = 4
) (
    input logic [COORD_WIDTH-1:0] current_x,
    input logic [COORD_WIDTH-1:0] current_y,

    input logic [31:0] packet_data,
    input logic packet_valid,

    output logic [2:0] requested_output,
    output logic request_valid
);

    localparam logic [2:0] LOCAL = 3'd0;
    localparam logic [2:0] NORTH = 3'd1;
    localparam logic [2:0] SOUTH = 3'd2;
    localparam logic [2:0] EAST  = 3'd3;
    localparam logic [2:0] WEST  = 3'd4;

    logic [3:0] dest_x;
    logic [3:0] dest_y;

    assign dest_x = packet_data[31:28];
    assign dest_y = packet_data[27:24];

    always_comb begin
        requested_output = LOCAL;
        request_valid = 1'b0;

        if (packet_valid) begin
            request_valid = 1'b1;

            if (dest_x > current_x)
                requested_output = EAST;
            else if (dest_x < current_x)
                requested_output = WEST;
            else if (dest_y > current_y)
                requested_output = NORTH;
            else if (dest_y < current_y)
                requested_output = SOUTH;
            else
                requested_output = LOCAL;
        end
    end

endmodule