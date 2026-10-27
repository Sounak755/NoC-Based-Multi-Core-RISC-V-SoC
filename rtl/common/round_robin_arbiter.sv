
`timescale 1ns/1ps

module round_robin_arbiter #(
    parameter integer N = 4
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [N-1:0] req,
    input  wire         advance,
    output reg  [N-1:0] grant
);

    integer rr_start;
    integer candidate;
    integer k;
    reg found;

    // Select the first active requester from the current
    // round-robin starting position.
    always @(*) begin
        grant = {N{1'b0}};
        found = 1'b0;
        candidate = 0;

        for (k = 0; k < N; k = k + 1) begin
            candidate = rr_start + k;

            if (candidate >= N)
                candidate = candidate - N;

            if (!found && req[candidate]) begin
                grant[candidate] = 1'b1;
                found = 1'b1;
            end
        end
    end

    // Reset the starting requester to zero.
    // Rotate only when advance is asserted and a grant exists.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_start <= 0;
        end else if (advance && (|grant)) begin
            for (k = 0; k < N; k = k + 1) begin
                if (grant[k])
                    rr_start <= (k + 1) % N;
            end
        end
    end

endmodule
