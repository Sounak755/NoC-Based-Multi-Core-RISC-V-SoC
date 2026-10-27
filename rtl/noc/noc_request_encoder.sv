
`timescale 1ns/1ps

module noc_request_encoder (
    input logic clk,
    input logic rst_n,

    input logic txn_valid,
    output logic txn_ready,
    input logic [3:0] dest_x,
    input logic [3:0] dest_y,
    input logic [3:0] src_x,
    input logic [3:0] src_y,
    input logic txn_write,
    input logic [2:0] txn_funct3,
    input logic [31:0] txn_addr,
    input logic [31:0] txn_wdata,

    output logic flit_valid,
    input logic flit_ready,
    output logic [31:0] flit_data,
    output logic flit_last
);

    typedef enum logic [2:0] {
        IDLE,
        SEND_0,
        SEND_1,
        SEND_2,
        SEND_3,
        SEND_4,
        SEND_5
    } state_t;

    state_t state;

    logic [3:0] saved_dest_x;
    logic [3:0] saved_dest_y;
    logic [3:0] saved_src_x;
    logic [3:0] saved_src_y;

    logic [77:0] saved_payload;
    logic [12:0] payload_chunk;
    logic [2:0] sequence_index;

    assign txn_ready = (state == IDLE) && rst_n;
    assign flit_valid = (state != IDLE);
    assign flit_last = (state == SEND_5);

    always_comb begin
        sequence_index = 3'd0;
        payload_chunk = 13'd0;

        case (state)
            SEND_0: begin
                sequence_index = 3'd0;
                payload_chunk = saved_payload[77:65];
            end

            SEND_1: begin
                sequence_index = 3'd1;
                payload_chunk = saved_payload[64:52];
            end

            SEND_2: begin
                sequence_index = 3'd2;
                payload_chunk = saved_payload[51:39];
            end

            SEND_3: begin
                sequence_index = 3'd3;
                payload_chunk = saved_payload[38:26];
            end

            SEND_4: begin
                sequence_index = 3'd4;
                payload_chunk = saved_payload[25:13];
            end

            SEND_5: begin
                sequence_index = 3'd5;
                payload_chunk = saved_payload[12:0];
            end

            default: begin
                sequence_index = 3'd0;
                payload_chunk = 13'd0;
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
            state <= IDLE;
            saved_dest_x <= 4'd0;
            saved_dest_y <= 4'd0;
            saved_src_x <= 4'd0;
            saved_src_y <= 4'd0;
            saved_payload <= 78'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (txn_valid && txn_ready) begin
                        saved_dest_x <= dest_x;
                        saved_dest_y <= dest_y;
                        saved_src_x <= src_x;
                        saved_src_y <= src_y;

                        saved_payload <= {
                            10'b0,
                            txn_write,
                            txn_funct3,
                            txn_addr,
                            txn_wdata
                        };

                        state <= SEND_0;
                    end
                end

                SEND_0: if (flit_ready) state <= SEND_1;
                SEND_1: if (flit_ready) state <= SEND_2;
                SEND_2: if (flit_ready) state <= SEND_3;
                SEND_3: if (flit_ready) state <= SEND_4;
                SEND_4: if (flit_ready) state <= SEND_5;
                SEND_5: if (flit_ready) state <= IDLE;

                default: state <= IDLE;
            endcase
        end
    end

endmodule
