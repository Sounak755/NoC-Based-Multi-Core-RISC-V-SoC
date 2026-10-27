
`timescale 1ns/1ps

module noc_router #(
    parameter integer DATA_WIDTH  = 32,
    parameter integer COORD_WIDTH = 4,
    parameter integer FIFO_DEPTH  = 8
) (
    input logic clk,
    input logic rst_n,

    input logic [COORD_WIDTH-1:0] router_x,
    input logic [COORD_WIDTH-1:0] router_y,

    input logic [DATA_WIDTH-1:0] local_data_in,
    input logic local_valid_in,
    output wire local_ready_in,

    input logic [DATA_WIDTH-1:0] north_data_in,
    input logic north_valid_in,
    output wire north_ready_in,

    input logic [DATA_WIDTH-1:0] south_data_in,
    input logic south_valid_in,
    output wire south_ready_in,

    input logic [DATA_WIDTH-1:0] east_data_in,
    input logic east_valid_in,
    output wire east_ready_in,

    input logic [DATA_WIDTH-1:0] west_data_in,
    input logic west_valid_in,
    output wire west_ready_in,

    output logic [DATA_WIDTH-1:0] local_data_out,
    output logic local_valid_out,
    input logic local_ready_out,

    output logic [DATA_WIDTH-1:0] north_data_out,
    output logic north_valid_out,
    input logic north_ready_out,

    output logic [DATA_WIDTH-1:0] south_data_out,
    output logic south_valid_out,
    input logic south_ready_out,

    output logic [DATA_WIDTH-1:0] east_data_out,
    output logic east_valid_out,
    input logic east_ready_out,

    output logic [DATA_WIDTH-1:0] west_data_out,
    output logic west_valid_out,
    input logic west_ready_out
);

    localparam integer PORTS   = 5;
    localparam integer P_LOCAL = 0;
    localparam integer P_NORTH = 1;
    localparam integer P_SOUTH = 2;
    localparam integer P_EAST  = 3;
    localparam integer P_WEST  = 4;

    wire [DATA_WIDTH-1:0] input_data [0:PORTS-1];
    wire [PORTS-1:0] input_valid;
    wire [PORTS-1:0] input_ready;

    assign input_data[P_LOCAL] = local_data_in;
    assign input_data[P_NORTH] = north_data_in;
    assign input_data[P_SOUTH] = south_data_in;
    assign input_data[P_EAST]  = east_data_in;
    assign input_data[P_WEST]  = west_data_in;

    assign input_valid[P_LOCAL] = local_valid_in;
    assign input_valid[P_NORTH] = north_valid_in;
    assign input_valid[P_SOUTH] = south_valid_in;
    assign input_valid[P_EAST]  = east_valid_in;
    assign input_valid[P_WEST]  = west_valid_in;

    assign local_ready_in = input_ready[P_LOCAL];
    assign north_ready_in = input_ready[P_NORTH];
    assign south_ready_in = input_ready[P_SOUTH];
    assign east_ready_in  = input_ready[P_EAST];
    assign west_ready_in  = input_ready[P_WEST];

    wire [DATA_WIDTH-1:0] buffered_data [0:PORTS-1];
    wire [PORTS-1:0] buffered_valid;
    logic [PORTS-1:0] input_pop_ready;

    genvar g;

    generate
        for (g = 0; g < PORTS; g = g + 1) begin : INPUT_BUFFERS
            router_input_buffer #(
                .DATA_WIDTH(DATA_WIDTH),
                .DEPTH(FIFO_DEPTH)
            ) input_buffer_inst (
                .clk(clk),
                .rst_n(rst_n),
                .data_in(input_data[g]),
                .valid_in(input_valid[g]),
                .ready_in(input_ready[g]),
                .data_out(buffered_data[g]),
                .valid_out(buffered_valid[g]),
                .ready_out(input_pop_ready[g])
            );
        end
    endgenerate

    wire [2:0] requested_output [0:PORTS-1];
    wire [PORTS-1:0] request_valid;

    generate
        for (g = 0; g < PORTS; g = g + 1) begin : ROUTE_REQUESTS
            router_route_request #(
                .COORD_WIDTH(COORD_WIDTH)
            ) route_request_inst (
                .current_x(router_x),
                .current_y(router_y),
                .packet_data(buffered_data[g][31:0]),
                .packet_valid(buffered_valid[g]),
                .requested_output(requested_output[g]),
                .request_valid(request_valid[g])
            );
        end
    endgenerate

    // One-hot grant vector per output.
    logic [PORTS-1:0] grant_by_output [0:PORTS-1];
    localparam integer RR_WIDTH = $clog2(PORTS);
    logic [RR_WIDTH-1:0] rr_start [0:PORTS-1];

    integer arb_o;
    integer arb_k;
    logic [RR_WIDTH:0] arb_candidate;
    integer arb_selected;

    // Select one requesting input for each output.
    // Assign the entire grant vector, avoiding partial-vector updates.
    always @(*) begin
        for (arb_o = 0; arb_o < PORTS; arb_o = arb_o + 1) begin
            grant_by_output[arb_o] = {PORTS{1'b0}};
            arb_selected = -1;

            for (arb_k = 0; arb_k < PORTS; arb_k = arb_k + 1) begin
                arb_candidate = {1'b0, rr_start[arb_o]} + arb_k;

                if (arb_candidate >= PORTS)
                arb_candidate = arb_candidate - PORTS;
                if ((arb_selected == -1) &&
                    request_valid[arb_candidate] &&
                    (requested_output[arb_candidate] == arb_o)) begin
                    arb_selected = arb_candidate;
                end
            end

            if (arb_selected >= 0)
                grant_by_output[arb_o] =
                    ({{(PORTS-1){1'b0}}, 1'b1} << arb_selected);
        end
    end

    logic [DATA_WIDTH-1:0] output_data [0:PORTS-1];
    logic [PORTS-1:0] output_valid;
    wire [PORTS-1:0] output_ready;

    assign output_ready[P_LOCAL] = local_ready_out;
    assign output_ready[P_NORTH] = north_ready_out;
    assign output_ready[P_SOUTH] = south_ready_out;
    assign output_ready[P_EAST]  = east_ready_out;
    assign output_ready[P_WEST]  = west_ready_out;

    integer cross_o;
    integer cross_p;

    // Crossbar: route the selected input to its granted output.
    always @(*) begin
        for (cross_o = 0; cross_o < PORTS; cross_o = cross_o + 1) begin
            output_data[cross_o] = {DATA_WIDTH{1'b0}};
            output_valid[cross_o] = 1'b0;
        end

        input_pop_ready = {PORTS{1'b0}};

        for (cross_o = 0; cross_o < PORTS; cross_o = cross_o + 1) begin
            for (cross_p = 0; cross_p < PORTS; cross_p = cross_p + 1) begin
                if (grant_by_output[cross_o][cross_p]) begin
                    output_data[cross_o] = buffered_data[cross_p];
                    output_valid[cross_o] = buffered_valid[cross_p];
                    input_pop_ready[cross_p] = output_ready[cross_o];
                end
            end
        end

        // Drive the module ports in the same process that computes the
        // crossbar. This avoids stale/X outputs from a separate process
        // observing an unpacked variable array in some simulators.
        local_data_out  = output_data[P_LOCAL];
        local_valid_out = output_valid[P_LOCAL];
        north_data_out  = output_data[P_NORTH];
        north_valid_out = output_valid[P_NORTH];
        south_data_out  = output_data[P_SOUTH];
        south_valid_out = output_valid[P_SOUTH];
        east_data_out   = output_data[P_EAST];
        east_valid_out  = output_valid[P_EAST];
        west_data_out   = output_data[P_WEST];
        west_valid_out  = output_valid[P_WEST];
    end

    integer reset_idx;
    integer seq_o;
    integer seq_p;

    // Rotate output priority after a successful transfer.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (reset_idx = 0; reset_idx < PORTS; reset_idx = reset_idx + 1)
                rr_start[reset_idx] <= 0;
        end else begin
            for (seq_o = 0; seq_o < PORTS; seq_o = seq_o + 1) begin
                if (output_valid[seq_o] && output_ready[seq_o]) begin
                    for (seq_p = 0; seq_p < PORTS; seq_p = seq_p + 1) begin
                        if (grant_by_output[seq_o][seq_p])
                            rr_start[seq_o] <=
                                (seq_p == PORTS-1) ? 0 : seq_p + 1;
                    end
                end
            end
        end
    end


endmodule
