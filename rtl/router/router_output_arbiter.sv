
`timescale 1ns/1ps

module router_output_arbiter #(
    parameter int N = 5
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [N-1:0] request,
    input  logic         advance,
    output logic [N-1:0] grant
);

    round_robin_arbiter #(
        .N(N)
    ) arbiter_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .req     (request),
        .advance (advance),
        .grant   (grant)
    );

endmodule
