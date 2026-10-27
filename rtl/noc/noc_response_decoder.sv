
`timescale 1ns/1ps

module noc_response_decoder (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        flit_valid,
    output logic        flit_ready,
    input  logic [31:0] flit_data,

    output logic        resp_valid,
    input  logic        resp_ready,
    output logic [31:0] resp_rdata,
    output logic        resp_error,
    output logic [3:0]  resp_src_x,
    output logic [3:0]  resp_src_y,
    output logic [3:0]  resp_dest_x,
    output logic [3:0]  resp_dest_y,
    output logic        protocol_error
);

    // One context per source node: {source_x[0], source_y[0]}.
    logic [38:0] context_payload [0:3];
    logic [7:0]  context_dest    [0:3];
    logic [7:0]  context_source  [0:3];
    logic [2:0]  expected_index  [0:3];
    logic        context_active  [0:3];

    logic [3:0] incoming_dest_x;
    logic [3:0] incoming_dest_y;
    logic [3:0] incoming_src_x;
    logic [3:0] incoming_src_y;
    logic [7:0] incoming_dest;
    logic [7:0] incoming_source;
    logic [1:0] source_slot;
    logic [2:0] incoming_index;
    logic [12:0] incoming_chunk;

    logic coordinates_valid;
    logic [38:0] completed_payload;

    integer i;

    assign incoming_dest_x = flit_data[31:28];
    assign incoming_dest_y = flit_data[27:24];
    assign incoming_src_x  = flit_data[23:20];
    assign incoming_src_y  = flit_data[19:16];

    assign incoming_dest   = flit_data[31:24];
    assign incoming_source = flit_data[23:16];
    assign incoming_index  = flit_data[15:13];
    assign incoming_chunk  = flit_data[12:0];

    assign source_slot = {
        incoming_src_x[0],
        incoming_src_y[0]
    };

    assign coordinates_valid =
        (incoming_dest_x <= 4'd1) &&
        (incoming_dest_y <= 4'd1) &&
        (incoming_src_x  <= 4'd1) &&
        (incoming_src_y  <= 4'd1);

    always_comb begin
        completed_payload = context_payload[source_slot];

        case (incoming_index)
            3'd0: completed_payload[38:26] = incoming_chunk;
            3'd1: completed_payload[25:13] = incoming_chunk;
            3'd2: completed_payload[12:0]  = incoming_chunk;
            default: ;
        endcase
    end

    // Stop accepting flits while a completed response is waiting
    // for its consumer.
    assign flit_ready = rst_n && !resp_valid;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            resp_valid     <= 1'b0;
            resp_rdata     <= 32'd0;
            resp_error     <= 1'b0;
            resp_src_x     <= 4'd0;
            resp_src_y     <= 4'd0;
            resp_dest_x    <= 4'd0;
            resp_dest_y    <= 4'd0;
            protocol_error <= 1'b0;

            for (i = 0; i < 4; i = i + 1) begin
                context_payload[i] <= 39'd0;
                context_dest[i]    <= 8'd0;
                context_source[i]  <= 8'd0;
                expected_index[i]  <= 3'd0;
                context_active[i]  <= 1'b0;
            end
        end else begin
            protocol_error <= 1'b0;

            if (resp_valid && resp_ready)
                resp_valid <= 1'b0;

            if (flit_valid && flit_ready) begin
                if (!coordinates_valid) begin
                    protocol_error <= 1'b1;

                    if ((incoming_src_x <= 4'd1) &&
                        (incoming_src_y <= 4'd1)) begin
                        context_active[source_slot] <= 1'b0;
                        expected_index[source_slot] <= 3'd0;
                    end
                end else begin
                    case (incoming_index)

                        // First response flit. The marker is bit 12
                        // of this flit's payload chunk.
                        3'd0: begin
                            if (incoming_chunk[12] != 1'b1) begin
                                protocol_error <= 1'b1;
                                context_active[source_slot] <= 1'b0;
                                expected_index[source_slot] <= 3'd0;
                            end else begin
                                context_payload[source_slot][38:26]
                                    <= incoming_chunk;

                                context_dest[source_slot] <= incoming_dest;
                                context_source[source_slot] <= incoming_source;
                                expected_index[source_slot] <= 3'd1;
                                context_active[source_slot] <= 1'b1;
                            end
                        end

                        // Second flit must match the same packet.
                        3'd1: begin
                            if (context_active[source_slot] &&
                                context_dest[source_slot] == incoming_dest &&
                                context_source[source_slot] == incoming_source &&
                                expected_index[source_slot] == 3'd1) begin

                                context_payload[source_slot][25:13]
                                    <= incoming_chunk;

                                expected_index[source_slot] <= 3'd2;
                            end else begin
                                context_active[source_slot] <= 1'b0;
                                expected_index[source_slot] <= 3'd0;
                                protocol_error <= 1'b1;
                            end
                        end

                        // Final flit completes the response.
                        3'd2: begin
                            if (context_active[source_slot] &&
                                context_dest[source_slot] == incoming_dest &&
                                context_source[source_slot] == incoming_source &&
                                expected_index[source_slot] == 3'd2) begin

                                resp_rdata <= completed_payload[31:0];
                                resp_error <= completed_payload[32];

                                resp_src_x  <= incoming_src_x;
                                resp_src_y  <= incoming_src_y;
                                resp_dest_x <= incoming_dest_x;
                                resp_dest_y <= incoming_dest_y;

                                resp_valid <= 1'b1;
                            end else begin
                                protocol_error <= 1'b1;
                            end

                            context_active[source_slot] <= 1'b0;
                            expected_index[source_slot] <= 3'd0;
                        end

                        default: begin
                            context_active[source_slot] <= 1'b0;
                            expected_index[source_slot] <= 3'd0;
                            protocol_error <= 1'b1;
                        end

                    endcase
                end
            end
        end
    end

endmodule
