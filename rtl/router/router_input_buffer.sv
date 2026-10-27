`timescale 1ns/1ps

module router_input_buffer #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 8
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Upstream interface
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  valid_in,
    output logic                  ready_in,

    // Downstream interface
    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  valid_out,
    input  logic                  ready_out
);

    logic fifo_full;
    logic fifo_empty;
    logic fifo_wr_en;
    logic fifo_rd_en;

    // Upstream can send data while the FIFO has space.
    assign ready_in = rst_n && !fifo_full;

    // Write only when a valid transfer is accepted.
    assign fifo_wr_en = valid_in && ready_in;

    // The FIFO head is valid whenever it is not empty.
    assign valid_out = rst_n && !fifo_empty;

    // Consume the head only when downstream accepts it.
    assign fifo_rd_en = valid_out && ready_out;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) input_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(fifo_wr_en),
        .wr_data(data_in),
        .rd_en(fifo_rd_en),
        .rd_data(data_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );

endmodule