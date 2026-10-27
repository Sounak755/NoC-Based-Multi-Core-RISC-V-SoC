
`timescale 1ns/1ps

module noc_mesh_2x2 #(
    parameter integer DATA_WIDTH  = 32,
    parameter integer COORD_WIDTH = 4,
    parameter integer FIFO_DEPTH  = 8
) (
    input logic clk,
    input logic rst_n,

    // Node 00: coordinate (0,0)
    input  logic [DATA_WIDTH-1:0] local_data_in_00,
    input  logic local_valid_in_00,
    output wire local_ready_in_00,
    output wire [DATA_WIDTH-1:0] local_data_out_00,
    output wire local_valid_out_00,
    input  logic local_ready_out_00,

    // Node 10: coordinate (1,0)
    input  logic [DATA_WIDTH-1:0] local_data_in_10,
    input  logic local_valid_in_10,
    output wire local_ready_in_10,
    output wire [DATA_WIDTH-1:0] local_data_out_10,
    output wire local_valid_out_10,
    input  logic local_ready_out_10,

    // Node 01: coordinate (0,1)
    input  logic [DATA_WIDTH-1:0] local_data_in_01,
    input  logic local_valid_in_01,
    output wire local_ready_in_01,
    output wire [DATA_WIDTH-1:0] local_data_out_01,
    output wire local_valid_out_01,
    input  logic local_ready_out_01,

    // Node 11: coordinate (1,1)
    input  logic [DATA_WIDTH-1:0] local_data_in_11,
    input  logic local_valid_in_11,
    output wire local_ready_in_11,
    output wire [DATA_WIDTH-1:0] local_data_out_11,
    output wire local_valid_out_11,
    input  logic local_ready_out_11
);

    // =========================================================
    // Directed inter-router links
    //
    // Each direction has independent data and valid signals.
    // The receiver's input-ready signal returns to the sender's
    // output-ready port. Opposite directions are never tied.
    // =========================================================

    // R00 EAST -> R10 WEST
    wire [DATA_WIDTH-1:0] link_00_to_10_data;
    wire link_00_to_10_valid;
    wire link_10_west_input_ready;

    // R10 WEST -> R00 EAST
    wire [DATA_WIDTH-1:0] link_10_to_00_data;
    wire link_10_to_00_valid;
    wire link_00_east_input_ready;

    // R01 EAST -> R11 WEST
    wire [DATA_WIDTH-1:0] link_01_to_11_data;
    wire link_01_to_11_valid;
    wire link_11_west_input_ready;

    // R11 WEST -> R01 EAST
    wire [DATA_WIDTH-1:0] link_11_to_01_data;
    wire link_11_to_01_valid;
    wire link_01_east_input_ready;

    // R00 NORTH -> R01 SOUTH
    wire [DATA_WIDTH-1:0] link_00_to_01_data;
    wire link_00_to_01_valid;
    wire link_01_south_input_ready;

    // R01 SOUTH -> R00 NORTH
    wire [DATA_WIDTH-1:0] link_01_to_00_data;
    wire link_01_to_00_valid;
    wire link_00_north_input_ready;

    // R10 NORTH -> R11 SOUTH
    wire [DATA_WIDTH-1:0] link_10_to_11_data;
    wire link_10_to_11_valid;
    wire link_11_south_input_ready;

    // R11 SOUTH -> R10 NORTH
    wire [DATA_WIDTH-1:0] link_11_to_10_data;
    wire link_11_to_10_valid;
    wire link_10_north_input_ready;

    // =========================================================
    // R00: coordinate (0,0)
    // Neighbors: EAST=R10, NORTH=R01
    // =========================================================

    noc_router #(
        .DATA_WIDTH(DATA_WIDTH),
        .COORD_WIDTH(COORD_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) R00 (
        .clk(clk),
        .rst_n(rst_n),
        .router_x(COORD_WIDTH'(0)),
        .router_y(COORD_WIDTH'(0)),

        .local_data_in(local_data_in_00),
        .local_valid_in(local_valid_in_00),
        .local_ready_in(local_ready_in_00),

        .north_data_in(link_01_to_00_data),
        .north_valid_in(link_01_to_00_valid),
        .north_ready_in(link_00_north_input_ready),

        .south_data_in({DATA_WIDTH{1'b0}}),
        .south_valid_in(1'b0),
        .south_ready_in(),

        .east_data_in(link_10_to_00_data),
        .east_valid_in(link_10_to_00_valid),
        .east_ready_in(link_00_east_input_ready),

        .west_data_in({DATA_WIDTH{1'b0}}),
        .west_valid_in(1'b0),
        .west_ready_in(),

        .local_data_out(local_data_out_00),
        .local_valid_out(local_valid_out_00),
        .local_ready_out(local_ready_out_00),

        .north_data_out(link_00_to_01_data),
        .north_valid_out(link_00_to_01_valid),
        .north_ready_out(link_01_south_input_ready),

        .south_data_out(),
        .south_valid_out(),
        .south_ready_out(1'b0),

        .east_data_out(link_00_to_10_data),
        .east_valid_out(link_00_to_10_valid),
        .east_ready_out(link_10_west_input_ready),

        .west_data_out(),
        .west_valid_out(),
        .west_ready_out(1'b0)
    );

    // =========================================================
    // R10: coordinate (1,0)
    // Neighbors: WEST=R00, NORTH=R11
    // =========================================================

    noc_router #(
        .DATA_WIDTH(DATA_WIDTH),
        .COORD_WIDTH(COORD_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) R10 (
        .clk(clk),
        .rst_n(rst_n),
        .router_x(COORD_WIDTH'(1)),
        .router_y(COORD_WIDTH'(0)),

        .local_data_in(local_data_in_10),
        .local_valid_in(local_valid_in_10),
        .local_ready_in(local_ready_in_10),

        .north_data_in(link_11_to_10_data),
        .north_valid_in(link_11_to_10_valid),
        .north_ready_in(link_10_north_input_ready),

        .south_data_in({DATA_WIDTH{1'b0}}),
        .south_valid_in(1'b0),
        .south_ready_in(),

        .east_data_in({DATA_WIDTH{1'b0}}),
        .east_valid_in(1'b0),
        .east_ready_in(),

        .west_data_in(link_00_to_10_data),
        .west_valid_in(link_00_to_10_valid),
        .west_ready_in(link_10_west_input_ready),

        .local_data_out(local_data_out_10),
        .local_valid_out(local_valid_out_10),
        .local_ready_out(local_ready_out_10),

        .north_data_out(link_10_to_11_data),
        .north_valid_out(link_10_to_11_valid),
        .north_ready_out(link_11_south_input_ready),

        .south_data_out(),
        .south_valid_out(),
        .south_ready_out(1'b0),

        .east_data_out(),
        .east_valid_out(),
        .east_ready_out(1'b0),

        .west_data_out(link_10_to_00_data),
        .west_valid_out(link_10_to_00_valid),
        .west_ready_out(link_00_east_input_ready)
    );

    // =========================================================
    // R01: coordinate (0,1)
    // Neighbors: SOUTH=R00, EAST=R11
    // =========================================================

    noc_router #(
        .DATA_WIDTH(DATA_WIDTH),
        .COORD_WIDTH(COORD_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) R01 (
        .clk(clk),
        .rst_n(rst_n),
        .router_x(COORD_WIDTH'(0)),
        .router_y(COORD_WIDTH'(1)),

        .local_data_in(local_data_in_01),
        .local_valid_in(local_valid_in_01),
        .local_ready_in(local_ready_in_01),

        .north_data_in({DATA_WIDTH{1'b0}}),
        .north_valid_in(1'b0),
        .north_ready_in(),

        .south_data_in(link_00_to_01_data),
        .south_valid_in(link_00_to_01_valid),
        .south_ready_in(link_01_south_input_ready),

        .east_data_in(link_11_to_01_data),
        .east_valid_in(link_11_to_01_valid),
        .east_ready_in(link_01_east_input_ready),

        .west_data_in({DATA_WIDTH{1'b0}}),
        .west_valid_in(1'b0),
        .west_ready_in(),

        .local_data_out(local_data_out_01),
        .local_valid_out(local_valid_out_01),
        .local_ready_out(local_ready_out_01),

        .north_data_out(),
        .north_valid_out(),
        .north_ready_out(1'b0),

        .south_data_out(link_01_to_00_data),
        .south_valid_out(link_01_to_00_valid),
        .south_ready_out(link_00_north_input_ready),

        .east_data_out(link_01_to_11_data),
        .east_valid_out(link_01_to_11_valid),
        .east_ready_out(link_11_west_input_ready),

        .west_data_out(),
        .west_valid_out(),
        .west_ready_out(1'b0)
    );

    // =========================================================
    // R11: coordinate (1,1)
    // Neighbors: SOUTH=R10, WEST=R01
    // =========================================================

    noc_router #(
        .DATA_WIDTH(DATA_WIDTH),
        .COORD_WIDTH(COORD_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) R11 (
        .clk(clk),
        .rst_n(rst_n),
        .router_x(COORD_WIDTH'(1)),
        .router_y(COORD_WIDTH'(1)),

        .local_data_in(local_data_in_11),
        .local_valid_in(local_valid_in_11),
        .local_ready_in(local_ready_in_11),

        .north_data_in({DATA_WIDTH{1'b0}}),
        .north_valid_in(1'b0),
        .north_ready_in(),

        .south_data_in(link_10_to_11_data),
        .south_valid_in(link_10_to_11_valid),
        .south_ready_in(link_11_south_input_ready),

        .east_data_in({DATA_WIDTH{1'b0}}),
        .east_valid_in(1'b0),
        .east_ready_in(),

        .west_data_in(link_01_to_11_data),
        .west_valid_in(link_01_to_11_valid),
        .west_ready_in(link_11_west_input_ready),

        .local_data_out(local_data_out_11),
        .local_valid_out(local_valid_out_11),
        .local_ready_out(local_ready_out_11),

        .north_data_out(),
        .north_valid_out(),
        .north_ready_out(1'b0),

        .south_data_out(link_11_to_10_data),
        .south_valid_out(link_11_to_10_valid),
        .south_ready_out(link_10_north_input_ready),

        .east_data_out(),
        .east_valid_out(),
        .east_ready_out(1'b0),

        .west_data_out(link_11_to_01_data),
        .west_valid_out(link_11_to_01_valid),
        .west_ready_out(link_01_east_input_ready)
    );

endmodule
