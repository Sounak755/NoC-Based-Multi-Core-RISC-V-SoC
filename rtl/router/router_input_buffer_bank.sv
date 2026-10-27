`timescale 1ns/1ps

module router_input_buffer_bank #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 8
) (
    input logic clk,
    input logic rst_n,

    // NORTH input
    input logic [DATA_WIDTH-1:0] north_data_in,
    input logic north_valid_in,
    output logic north_ready_in,
    output logic [DATA_WIDTH-1:0] north_data_out,
    output logic north_valid_out,
    input logic north_ready_out,

    // SOUTH input
    input logic [DATA_WIDTH-1:0] south_data_in,
    input logic south_valid_in,
    output logic south_ready_in,
    output logic [DATA_WIDTH-1:0] south_data_out,
    output logic south_valid_out,
    input logic south_ready_out,

    // EAST input
    input logic [DATA_WIDTH-1:0] east_data_in,
    input logic east_valid_in,
    output logic east_ready_in,
    output logic [DATA_WIDTH-1:0] east_data_out,
    output logic east_valid_out,
    input logic east_ready_out,

    // WEST input
    input logic [DATA_WIDTH-1:0] west_data_in,
    input logic west_valid_in,
    output logic west_ready_in,
    output logic [DATA_WIDTH-1:0] west_data_out,
    output logic west_valid_out,
    input logic west_ready_out,

    // LOCAL input
    input logic [DATA_WIDTH-1:0] local_data_in,
    input logic local_valid_in,
    output logic local_ready_in,
    output logic [DATA_WIDTH-1:0] local_data_out,
    output logic local_valid_out,
    input logic local_ready_out
);

    router_input_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) north_buffer (
        .clk(clk), .rst_n(rst_n),
        .data_in(north_data_in),
        .valid_in(north_valid_in),
        .ready_in(north_ready_in),
        .data_out(north_data_out),
        .valid_out(north_valid_out),
        .ready_out(north_ready_out)
    );

    router_input_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) south_buffer (
        .clk(clk), .rst_n(rst_n),
        .data_in(south_data_in),
        .valid_in(south_valid_in),
        .ready_in(south_ready_in),
        .data_out(south_data_out),
        .valid_out(south_valid_out),
        .ready_out(south_ready_out)
    );

    router_input_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) east_buffer (
        .clk(clk), .rst_n(rst_n),
        .data_in(east_data_in),
        .valid_in(east_valid_in),
        .ready_in(east_ready_in),
        .data_out(east_data_out),
        .valid_out(east_valid_out),
        .ready_out(east_ready_out)
    );

    router_input_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) west_buffer (
        .clk(clk), .rst_n(rst_n),
        .data_in(west_data_in),
        .valid_in(west_valid_in),
        .ready_in(west_ready_in),
        .data_out(west_data_out),
        .valid_out(west_valid_out),
        .ready_out(west_ready_out)
    );

    router_input_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) local_buffer (
        .clk(clk), .rst_n(rst_n),
        .data_in(local_data_in),
        .valid_in(local_valid_in),
        .ready_in(local_ready_in),
        .data_out(local_data_out),
        .valid_out(local_valid_out),
        .ready_out(local_ready_out)
    );

endmodule