
`timescale 1ns/1ps

module noc_request_decoder (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        flit_valid,
    output logic        flit_ready,
    input  logic [31:0] flit_data,

    output logic        req_valid,
    input  logic        req_ready,
    output logic        req_write,
    output logic [2:0]  req_funct3,
    output logic [31:0] req_addr,
    output logic [31:0] req_wdata,
    output logic [3:0]  req_src_x,
    output logic [3:0]  req_src_y,
    output logic [3:0]  req_dest_x,
    output logic [3:0]  req_dest_y,

    output logic        protocol_error
);

    // Four independent packet assembly contexts:
    // slot = {source_x[0], source_y[0]}
    logic [77:0] context_payload [0:3];
    logic [7:0]  context_dest    [0:3];
    logic [2:0]  expected_index  [0:3];
    logic        context_active  [0:3];

    logic [1:0] source_slot;
    logic [3:0] incoming_dest_x;
    logic [3:0] incoming_dest_y;
    logic [3:0] incoming_src_x;
    logic [3:0] incoming_src_y;
    logic [7:0] incoming_dest;
    logic [7:0] incoming_source;
    logic [2:0] incoming_index;
    logic [12:0] incoming_chunk;

    logic source_coordinates_valid;
    logic destination_coordinates_valid;

    logic [77:0] completed_payload;

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

    assign source_coordinates_valid =
        (incoming_src_x <= 4'd1) &&
        (incoming_src_y <= 4'd1);

    assign destination_coordinates_valid =
        (incoming_dest_x <= 4'd1) &&
        (incoming_dest_y <= 4'd1);

    // Reconstruct the full packet using the saved first
    // five chunks and the current sixth chunk.
    always_comb begin
        completed_payload = context_payload[source_slot];
        completed_payload[12:0] = incoming_chunk;
    end

    // Backpressure the input while a completed request
    // is waiting for the consumer.
    assign flit_ready = rst_n && !req_valid;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            req_valid      <= 1'b0;
            req_write      <= 1'b0;
            req_funct3     <= 3'd0;
            req_addr       <= 32'd0;
            req_wdata      <= 32'd0;
            req_src_x      <= 4'd0;
            req_src_y      <= 4'd0;
            req_dest_x     <= 4'd0;
            req_dest_y     <= 4'd0;
            protocol_error <= 1'b0;

            for (i = 0; i < 4; i = i + 1) begin
                context_payload[i] <= 78'd0;
                context_dest[i]    <= 8'd0;
                expected_index[i]  <= 3'd0;
                context_active[i]  <= 1'b0;
            end
        end else begin
            // Error is a one-cycle pulse.
            protocol_error <= 1'b0;

            if (req_valid && req_ready)
                req_valid <= 1'b0;

            if (flit_valid && flit_ready) begin

                // Only coordinates 0 and 1 exist in this mesh.
                if (!source_coordinates_valid ||
                    !destination_coordinates_valid) begin

                    protocol_error <= 1'b1;

                    // If source coordinates are valid, discard
                    // that source's incomplete packet.
                    if (source_coordinates_valid) begin
                        context_active[source_slot] <= 1'b0;
                        expected_index[source_slot] <= 3'd0;
                    end
                end else begin

                    case (incoming_index)

                        // FLIT 0: begin or restart this source's
                        // packet assembly context.
                        3'd0: begin
                            context_payload[source_slot][77:65]
                                <= incoming_chunk;

                            context_dest[source_slot]
                                <= incoming_dest;

                            expected_index[source_slot] <= 3'd1;
                            context_active[source_slot] <= 1'b1;
                        end

                        // FLITS 1-4: accept only in order.
                        3'd1, 3'd2, 3'd3, 3'd4: begin
                            if (context_active[source_slot] &&
                                context_dest[source_slot] == incoming_dest &&
                                expected_index[source_slot] == incoming_index) begin

                                case (incoming_index)
                                    3'd1:
                                        context_payload[source_slot][64:52]
                                            <= incoming_chunk;
                                    3'd2:
                                        context_payload[source_slot][51:39]
                                            <= incoming_chunk;
                                    3'd3:
                                        context_payload[source_slot][38:26]
                                            <= incoming_chunk;
                                    3'd4:
                                        context_payload[source_slot][25:13]
                                            <= incoming_chunk;
                                    default: begin
                                    end
                                endcase

                                expected_index[source_slot]
                                    <= incoming_index + 3'd1;
                            end else begin
                                context_active[source_slot] <= 1'b0;
                                expected_index[source_slot] <= 3'd0;
                                protocol_error <= 1'b1;
                            end
                        end

                        // FLIT 5: complete the request.
                        3'd5: begin
                            if (context_active[source_slot] &&
                                context_dest[source_slot] == incoming_dest &&
                                expected_index[source_slot] == 3'd5) begin

                                req_write  <= completed_payload[67];
                                req_funct3 <= completed_payload[66:64];
                                req_addr   <= completed_payload[63:32];
                                req_wdata  <= completed_payload[31:0];

                                req_src_x  <= incoming_src_x;
                                req_src_y  <= incoming_src_y;
                                req_dest_x <= incoming_dest_x;
                                req_dest_y <= incoming_dest_y;

                                req_valid <= 1'b1;
                            end else begin
                                protocol_error <= 1'b1;
                            end

                            context_active[source_slot] <= 1'b0;
                            expected_index[source_slot] <= 3'd0;
                        end

                        // Indices 6 and 7 are illegal.
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
