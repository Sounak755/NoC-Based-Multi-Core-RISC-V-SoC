
`timescale 1ns/1ps

module noc_memory_fabric_2x2 #(
    parameter integer FIFO_DEPTH = 8,
    parameter integer MEM_BYTES  = 1024
) (
    input  logic clk,
    input  logic rst_n,

    input  logic [3:0]        txn_valid,
    output logic [3:0]        txn_ready,
    input  logic [3:0][3:0]   txn_dest_x,
    input  logic [3:0][3:0]   txn_dest_y,
    input  logic [3:0]        txn_write,
    input  logic [3:0][2:0]   txn_funct3,
    input  logic [3:0][31:0]  txn_addr,
    input  logic [3:0][31:0]  txn_wdata,

    output logic [3:0]        node_resp_valid,
    input  logic [3:0]        node_resp_ready,
    output logic [3:0][3:0]   node_resp_src_x,
    output logic [3:0][3:0]   node_resp_src_y,
    output logic [3:0][3:0]   node_resp_dest_x,
    output logic [3:0][3:0]   node_resp_dest_y,
    output logic [3:0][31:0]  node_resp_rdata,
    output logic [3:0]        node_resp_error,
    output logic [3:0]        node_protocol_error,

    output logic [3:0]        source_resp_valid,
    input  logic [3:0]        source_resp_ready,
    output logic [3:0][3:0]   source_resp_src_x,
    output logic [3:0][3:0]   source_resp_src_y,
    output logic [3:0][3:0]   source_resp_dest_x,
    output logic [3:0][3:0]   source_resp_dest_y,
    output logic [3:0][31:0]  source_resp_rdata,
    output logic [3:0]        source_resp_error,
    output logic [3:0]        response_protocol_error
);

    logic [3:0][31:0] mesh_data_in;
    logic [3:0]       mesh_valid_in;
    logic [3:0]       mesh_ready_in;
    logic [3:0][31:0] mesh_data_out;
    logic [3:0]       mesh_valid_out;
    logic [3:0]       mesh_ready_out;

    logic [3:0]       req_dec_valid;
    logic [3:0]       req_dec_ready;
    logic [3:0]       req_dec_write;
    logic [3:0][2:0]  req_dec_funct3;
    logic [3:0][31:0] req_dec_addr;
    logic [3:0][31:0] req_dec_wdata;
    logic [3:0][3:0]  req_dec_src_x;
    logic [3:0][3:0]  req_dec_src_y;
    logic [3:0][3:0]  req_dec_dest_x;
    logic [3:0][3:0]  req_dec_dest_y;

    logic [3:0]       req_flit_valid;
    logic [3:0]       req_flit_ready;
    logic [3:0]       req_flit_last;
    logic [3:0][31:0] req_flit_data;

    logic [3:0]       rsp_flit_valid;
    logic [3:0]       rsp_flit_ready;
    logic [3:0]       rsp_flit_last;
    logic [3:0][31:0] rsp_flit_data;
    logic [3:0]       rsp_enc_ready;

    logic [3:0]       svc_resp_valid;
    logic [3:0]       svc_resp_ready;
    logic [3:0]       svc_resp_error;
    logic [3:0][3:0]  svc_resp_src_x;
    logic [3:0][3:0]  svc_resp_src_y;
    logic [3:0][3:0]  svc_resp_dest_x;
    logic [3:0][3:0]  svc_resp_dest_y;
    logic [3:0][31:0] svc_resp_rdata;

    logic [3:0]       monitor_valid;
    logic [3:0][3:0]  monitor_src_x;
    logic [3:0][3:0]  monitor_src_y;
    logic [3:0][3:0]  monitor_dest_x;
    logic [3:0][3:0]  monitor_dest_y;
    logic [3:0][31:0] monitor_rdata;
    logic [3:0]       monitor_error;
    logic [3:0]       monitor_can_accept;

    logic [3:0]       inject_locked;
    logic [3:0]       inject_response;
    logic [3:0]       inject_select_response;
    logic [3:0]       inject_valid;
    logic [3:0]       inject_ready;
    logic [3:0]       inject_last;
    logic [3:0][31:0] inject_data;

    // Unpacked arrays: one independent tracking entry per node/source slot.
    logic eject_type_by_source   [0:3][0:3];
    logic eject_active_by_source [0:3][0:3];

    logic [3:0][1:0] eject_source_slot;
    logic [3:0]      eject_is_response;

    logic [3:0] req_decoder_flit_valid;
    logic [3:0] rsp_decoder_flit_valid;
    logic [3:0] req_decoder_flit_ready;
    logic [3:0] rsp_decoder_flit_ready;
    logic [3:0] eject_flit_ready;
    logic [3:0] eject_flit_last;

    genvar n;
    generate
        for (n = 0; n < 4; n = n + 1) begin : GEN_NODE

            localparam logic [3:0] NODE_X =
                ((n == 1) || (n == 3)) ? 4'd1 : 4'd0;

            localparam logic [3:0] NODE_Y =
                ((n == 2) || (n == 3)) ? 4'd1 : 4'd0;

            noc_request_encoder u_request_encoder (
                .clk(clk),
                .rst_n(rst_n),
                .txn_valid(txn_valid[n]),
                .txn_ready(txn_ready[n]),
                .dest_x(txn_dest_x[n]),
                .dest_y(txn_dest_y[n]),
                .src_x(NODE_X),
                .src_y(NODE_Y),
                .txn_write(txn_write[n]),
                .txn_funct3(txn_funct3[n]),
                .txn_addr(txn_addr[n]),
                .txn_wdata(txn_wdata[n]),
                .flit_valid(req_flit_valid[n]),
                .flit_ready(req_flit_ready[n]),
                .flit_data(req_flit_data[n]),
                .flit_last(req_flit_last[n])
            );

            assign monitor_can_accept[n] =
                !monitor_valid[n] || node_resp_ready[n];

            assign svc_resp_ready[n] =
                rsp_enc_ready[n] && monitor_can_accept[n];

            noc_response_encoder u_response_encoder (
                .clk(clk),
                .rst_n(rst_n),
                .resp_valid(
                    svc_resp_valid[n] && monitor_can_accept[n]
                ),
                .resp_ready(rsp_enc_ready[n]),
                .resp_src_x(svc_resp_dest_x[n]),
                .resp_src_y(svc_resp_dest_y[n]),
                .resp_dest_x(svc_resp_src_x[n]),
                .resp_dest_y(svc_resp_src_y[n]),
                .resp_rdata(svc_resp_rdata[n]),
                .resp_error(svc_resp_error[n]),
                .flit_valid(rsp_flit_valid[n]),
                .flit_ready(rsp_flit_ready[n]),
                .flit_data(rsp_flit_data[n]),
                .flit_last(rsp_flit_last[n])
            );

            assign node_resp_valid[n]  = monitor_valid[n];
            assign node_resp_src_x[n]  = monitor_src_x[n];
            assign node_resp_src_y[n]  = monitor_src_y[n];
            assign node_resp_dest_x[n] = monitor_dest_x[n];
            assign node_resp_dest_y[n] = monitor_dest_y[n];
            assign node_resp_rdata[n]  = monitor_rdata[n];
            assign node_resp_error[n]  = monitor_error[n];

            always_ff @(posedge clk) begin
                if (!rst_n) begin
                    monitor_valid[n]  <= 1'b0;
                    monitor_src_x[n]  <= 4'd0;
                    monitor_src_y[n]  <= 4'd0;
                    monitor_dest_x[n] <= 4'd0;
                    monitor_dest_y[n] <= 4'd0;
                    monitor_rdata[n]  <= 32'd0;
                    monitor_error[n]  <= 1'b0;
                end else begin
                    if (monitor_valid[n] && node_resp_ready[n])
                        monitor_valid[n] <= 1'b0;

                    if (svc_resp_valid[n] && svc_resp_ready[n]) begin
                        monitor_valid[n]  <= 1'b1;
                        monitor_src_x[n]  <= svc_resp_src_x[n];
                        monitor_src_y[n]  <= svc_resp_src_y[n];
                        monitor_dest_x[n] <= svc_resp_dest_x[n];
                        monitor_dest_y[n] <= svc_resp_dest_y[n];
                        monitor_rdata[n]  <= svc_resp_rdata[n];
                        monitor_error[n]  <= svc_resp_error[n];
                    end
                end
            end

            // Lock injection to the selected packet until its last flit.
            always_comb begin
                inject_select_response[n] = inject_locked[n]
                    ? inject_response[n]
                    : rsp_flit_valid[n];

                if (inject_select_response[n]) begin
                    inject_valid[n] = rsp_flit_valid[n];
                    inject_data[n]  = rsp_flit_data[n];
                    inject_last[n]  = rsp_flit_last[n];
                end else begin
                    inject_valid[n] = req_flit_valid[n];
                    inject_data[n]  = req_flit_data[n];
                    inject_last[n]  = req_flit_last[n];
                end

                rsp_flit_ready[n] =
                    inject_ready[n] && inject_select_response[n];

                req_flit_ready[n] =
                    inject_ready[n] && !inject_select_response[n];
            end

            assign mesh_data_in[n]  = inject_data[n];
            assign mesh_valid_in[n] = inject_valid[n];
            assign inject_ready[n]  = mesh_ready_in[n];

            always_ff @(posedge clk) begin
                if (!rst_n) begin
                    inject_locked[n]   <= 1'b0;
                    inject_response[n] <= 1'b0;
                end else if (inject_valid[n] && inject_ready[n]) begin
                    if (inject_last[n]) begin
                        inject_locked[n] <= 1'b0;
                    end else if (!inject_locked[n]) begin
                        inject_locked[n]   <= 1'b1;
                        inject_response[n] <= inject_select_response[n];
                    end
                end
            end

            // Source X is in [23:20] and source Y in [19:16].
            // Use the LSBs of each 4-bit coordinate.
            assign eject_source_slot[n] = {
                mesh_data_out[n][20],
                mesh_data_out[n][16]
            };

            always_comb begin
                if (mesh_data_out[n][15:13] == 3'd0)
                    eject_is_response[n] = mesh_data_out[n][12];
                else
                    eject_is_response[n] =
                        eject_type_by_source[n][eject_source_slot[n]];

                req_decoder_flit_valid[n] =
                    mesh_valid_out[n] && !eject_is_response[n];

                rsp_decoder_flit_valid[n] =
                    mesh_valid_out[n] && eject_is_response[n];

                if (eject_is_response[n]) begin
                    eject_flit_ready[n] = rsp_decoder_flit_ready[n];
                    eject_flit_last[n] =
                        (mesh_data_out[n][15:13] == 3'd2);
                end else begin
                    eject_flit_ready[n] = req_decoder_flit_ready[n];
                    eject_flit_last[n] =
                        (mesh_data_out[n][15:13] == 3'd5);
                end
            end

            assign mesh_ready_out[n] = eject_flit_ready[n];

            // Track request/response type independently for each node.
            integer s;
            always_ff @(posedge clk) begin
                if (!rst_n) begin
                    for (s = 0; s < 4; s = s + 1) begin
                        eject_type_by_source[n][s]   <= 1'b0;
                        eject_active_by_source[n][s] <= 1'b0;
                    end
                end else if (
                    mesh_valid_out[n] && mesh_ready_out[n]
                ) begin
                    if (mesh_data_out[n][15:13] == 3'd0) begin
                        eject_type_by_source[n][eject_source_slot[n]]
                            <= mesh_data_out[n][12];

                        eject_active_by_source[n][eject_source_slot[n]]
                            <= 1'b1;
                    end

                    if (eject_flit_last[n]) begin
                        eject_active_by_source[n][eject_source_slot[n]]
                            <= 1'b0;
                    end
                end
            end

            noc_request_decoder u_request_decoder (
                .clk(clk),
                .rst_n(rst_n),
                .flit_valid(req_decoder_flit_valid[n]),
                .flit_ready(req_decoder_flit_ready[n]),
                .flit_data(mesh_data_out[n]),
                .req_valid(req_dec_valid[n]),
                .req_ready(req_dec_ready[n]),
                .req_write(req_dec_write[n]),
                .req_funct3(req_dec_funct3[n]),
                .req_addr(req_dec_addr[n]),
                .req_wdata(req_dec_wdata[n]),
                .req_src_x(req_dec_src_x[n]),
                .req_src_y(req_dec_src_y[n]),
                .req_dest_x(req_dec_dest_x[n]),
                .req_dest_y(req_dec_dest_y[n]),
                .protocol_error(node_protocol_error[n])
            );

            noc_response_decoder u_response_decoder (
                .clk(clk),
                .rst_n(rst_n),
                .flit_valid(rsp_decoder_flit_valid[n]),
                .flit_ready(rsp_decoder_flit_ready[n]),
                .flit_data(mesh_data_out[n]),
                .resp_valid(source_resp_valid[n]),
                .resp_ready(source_resp_ready[n]),
                .resp_rdata(source_resp_rdata[n]),
                .resp_error(source_resp_error[n]),
                .resp_src_x(source_resp_src_x[n]),
                .resp_src_y(source_resp_src_y[n]),
                .resp_dest_x(source_resp_dest_x[n]),
                .resp_dest_y(source_resp_dest_y[n]),
                .protocol_error(response_protocol_error[n])
            );

            noc_memory_service #(
                .NODE_X(NODE_X),
                .NODE_Y(NODE_Y),
                .MEM_BYTES(MEM_BYTES)
            ) u_memory_service (
                .clk(clk),
                .rst_n(rst_n),
                .req_valid(req_dec_valid[n]),
                .req_ready(req_dec_ready[n]),
                .req_write(req_dec_write[n]),
                .req_funct3(req_dec_funct3[n]),
                .req_addr(req_dec_addr[n]),
                .req_wdata(req_dec_wdata[n]),
                .req_src_x(req_dec_src_x[n]),
                .req_src_y(req_dec_src_y[n]),
                .req_dest_x(req_dec_dest_x[n]),
                .req_dest_y(req_dec_dest_y[n]),
                .resp_valid(svc_resp_valid[n]),
                .resp_ready(svc_resp_ready[n]),
                .resp_src_x(svc_resp_src_x[n]),
                .resp_src_y(svc_resp_src_y[n]),
                .resp_dest_x(svc_resp_dest_x[n]),
                .resp_dest_y(svc_resp_dest_y[n]),
                .resp_rdata(svc_resp_rdata[n]),
                .resp_error(svc_resp_error[n])
            );

        end
    endgenerate

    noc_mesh_2x2 #(
        .DATA_WIDTH(32),
        .COORD_WIDTH(4),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_mesh (
        .clk(clk),
        .rst_n(rst_n),

        .local_data_in_00(mesh_data_in[0]),
        .local_valid_in_00(mesh_valid_in[0]),
        .local_ready_in_00(mesh_ready_in[0]),
        .local_data_out_00(mesh_data_out[0]),
        .local_valid_out_00(mesh_valid_out[0]),
        .local_ready_out_00(mesh_ready_out[0]),

        .local_data_in_10(mesh_data_in[1]),
        .local_valid_in_10(mesh_valid_in[1]),
        .local_ready_in_10(mesh_ready_in[1]),
        .local_data_out_10(mesh_data_out[1]),
        .local_valid_out_10(mesh_valid_out[1]),
        .local_ready_out_10(mesh_ready_out[1]),

        .local_data_in_01(mesh_data_in[2]),
        .local_valid_in_01(mesh_valid_in[2]),
        .local_ready_in_01(mesh_ready_in[2]),
        .local_data_out_01(mesh_data_out[2]),
        .local_valid_out_01(mesh_valid_out[2]),
        .local_ready_out_01(mesh_ready_out[2]),

        .local_data_in_11(mesh_data_in[3]),
        .local_valid_in_11(mesh_valid_in[3]),
        .local_ready_in_11(mesh_ready_in[3]),
        .local_data_out_11(mesh_data_out[3]),
        .local_valid_out_11(mesh_valid_out[3]),
        .local_ready_out_11(mesh_ready_out[3])
    );

endmodule
