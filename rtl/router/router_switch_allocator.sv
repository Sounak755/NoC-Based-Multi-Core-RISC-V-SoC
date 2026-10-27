
`timescale 1ns/1ps

module router_switch_allocator #(
    parameter integer PORTS = 5
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire [PORTS*PORTS-1:0]       req_by_input,
    input  wire [PORTS-1:0]             advance,
    output wire [PORTS*PORTS-1:0]       grant_by_output
);

    wire [PORTS-1:0] output_requests [0:PORTS-1];
    wire [PORTS-1:0] raw_grants [0:PORTS-1];
    wire [PORTS-1:0] final_grants [0:PORTS-1];

    wire [PORTS-1:0] accepted;

    genvar o, i;

    generate
        for (o = 0; o < PORTS; o = o + 1) begin : GEN_OUTPUT

            for (i = 0; i < PORTS; i = i + 1) begin : GEN_REQUEST
                assign output_requests[o][i] =
                    req_by_input[i*PORTS + o];
            end

            // Arbitration proposes one input for this output.
            round_robin_arbiter #(
                .N(PORTS)
            ) arbiter_inst (
                .clk     (clk),
                .rst_n   (rst_n),
                .req     (output_requests[o]),
                .advance (accepted[o]),
                .grant   (raw_grants[o])
            );

            // Advance only if the proposed grant is accepted
            // and the external downstream logic permits progress.
            assign accepted[o] = advance[o] &
                                 (|final_grants[o]);

            for (i = 0; i < PORTS; i = i + 1) begin : GEN_CONFLICT
                if (o == 0) begin : GEN_FIRST
                    assign final_grants[o][i] = raw_grants[o][i];
                end else begin : GEN_LATER
                    wire [o-1:0] earlier_winners;

                    for (genvar h = 0; h < o; h = h + 1) begin : GEN_CHECK
                        assign earlier_winners[h] = final_grants[h][i];
                    end

                    assign final_grants[o][i] =
                        raw_grants[o][i] & ~(|earlier_winners);
                end

                assign grant_by_output[o*PORTS + i] =
                    final_grants[o][i];
            end
        end
    endgenerate

endmodule
