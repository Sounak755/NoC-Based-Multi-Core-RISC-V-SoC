
`timescale 1ns/1ps

module noc_response_encoder (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        resp_valid,
    output logic        resp_ready,
    input  logic [3:0]  resp_src_x,
    input  logic [3:0]  resp_src_y,
    input  logic [3:0]  resp_dest_x,
    input  logic [3:0]  resp_dest_y,
    input  logic [31:0] resp_rdata,
    input  logic        resp_error,

    output logic        flit_valid,
    input  logic        flit_ready,
    output logic [31:0] flit_data,
    output logic        flit_last
);

    typedef enum logic [1:0] {
        IDLE,
        SEND_0,
        SEND_1,
        SEND_2
    } state_t;

    state_t state;

    logic [3:0]  saved_src_x;
    logic [3:0]  saved_src_y;
    logic [3:0]  saved_dest_x;
    logic [3:0]  saved_dest_y;
    logic [38:0] saved_payload;
    logic [12:0] payload_chunk;
    logic [2:0]  sequence_index;

    // Transaction-level handshake. This is independent of
    // the flit-level handshake used by the mesh.
    assign resp_ready = (state == IDLE) && rst_n;

    assign flit_valid = (state != IDLE);
    assign flit_last  = (state == SEND_2);

    always_comb begin
        sequence_index = 3'd0;
        payload_chunk  = 13'd0;

        case (state)
            SEND_0: begin
                sequence_index = 3'd0;
                payload_chunk  = saved_payload[38:26];
            end

            SEND_1: begin
                sequence_index = 3'd1;
                payload_chunk  = saved_payload[25:13];
            end

            SEND_2: begin
                sequence_index = 3'd2;
                payload_chunk  = saved_payload[12:0];
            end

            default: begin
                sequence_index = 3'd0;
                payload_chunk  = 13'd0;
            end
        endcase

        flit_data = {
            saved_dest_x,
            saved_dest_y,
            saved_src_x,
            saved_src_y,
            sequence_index,
            payload_chunk
        };
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state         <= IDLE;
            saved_src_x   <= 4'd0;
            saved_src_y   <= 4'd0;
            saved_dest_x  <= 4'd0;
            saved_dest_y  <= 4'd0;
            saved_payload <= 39'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (resp_valid && resp_ready) begin
                        saved_src_x  <= resp_src_x;
                        saved_src_y  <= resp_src_y;
                        saved_dest_x <= resp_dest_x;
                        saved_dest_y <= resp_dest_y;

                        // Payload layout:
                        // [38]    = response marker
                        // [37:33] = reserved
                        // [32]    = error
                        // [31:0]  = read data
                        //
                        // The marker is transmitted in bit 12
                        // of the first flit's payload chunk.
                        saved_payload <= {
                            1'b1,
                            5'b0,
                            resp_error,
                            resp_rdata
                        };

                        state <= SEND_0;
                    end
                end

                SEND_0: begin
                    if (flit_valid && flit_ready)
                        state <= SEND_1;
                end

                SEND_1: begin
                    if (flit_valid && flit_ready)
                        state <= SEND_2;
                end

                SEND_2: begin
                    if (flit_valid && flit_ready)
                        state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
