
`timescale 1ns/1ps

module rv32i_noc_multicore_subsystem #(
    parameter integer FIFO_DEPTH = 8,
    parameter integer MEM_BYTES  = 1024
) (
    input  logic clk,
    input  logic rst_n,

    // Independent instruction interfaces for the four cores.
    output logic [3:0][31:0] instruction_address,
    input  logic [3:0][31:0] instruction_data,

    // Per-core retirement/debug interfaces.
    output logic [3:0]       retire_valid,
    output logic [3:0][31:0] retire_pc,
    output logic [3:0][31:0] retire_instruction,
    output logic [3:0]       retire_rd_we,
    output logic [3:0][4:0]  retire_rd,
    output logic [3:0][31:0] retire_rd_data,

    // Per-core memory activity indicators.
    output logic [3:0] memory_request_active,
    output logic [3:0] memory_response_active,

    // Combined NoC protocol-error indicators.
    output logic [3:0] fabric_protocol_errors
);

    // ------------------------------------------------------------
    // CPU-to-adapter interfaces
    // ------------------------------------------------------------

    logic [3:0]        cpu_mem_read_enable;
    logic [3:0]        cpu_mem_write_enable;
    logic [3:0][2:0]   cpu_mem_funct3;
    logic [3:0][31:0]  cpu_mem_address;
    logic [3:0][31:0]  cpu_mem_write_data;
    logic [3:0][31:0]  cpu_mem_read_data;

    logic [3:0]        cpu_req_valid;
    logic [3:0]        cpu_req_ready;
    logic [3:0]        cpu_resp_valid;
    logic [3:0]        cpu_resp_ready;

    // ------------------------------------------------------------
    // Adapter-to-fabric request interfaces
    // ------------------------------------------------------------

    logic [3:0]        adapter_noc_req_valid;
    logic [3:0]        adapter_noc_req_ready;
    logic [3:0]        adapter_noc_req_write;
    logic [3:0][31:0]  adapter_noc_req_addr;
    logic [3:0][31:0]  adapter_noc_req_wdata;
    logic [3:0][2:0]   adapter_noc_req_funct3;

    logic [3:0]        adapter_noc_resp_valid;
    logic [3:0]        adapter_noc_resp_ready;
    logic [3:0][31:0]  adapter_noc_resp_rdata;

    // ------------------------------------------------------------
    // Shared fabric transaction interfaces
    // ------------------------------------------------------------

    logic [3:0]        txn_valid;
    logic [3:0]        txn_ready;
    logic [3:0][3:0]   txn_dest_x;
    logic [3:0][3:0]   txn_dest_y;
    logic [3:0]        txn_write;
    logic [3:0][2:0]   txn_funct3;
    logic [3:0][31:0]  txn_addr;
    logic [3:0][31:0]  txn_wdata;

    // Local response-monitor interface.
    logic [3:0]        node_resp_valid;
    logic [3:0]        node_resp_ready;
    logic [3:0][3:0]   node_resp_src_x;
    logic [3:0][3:0]   node_resp_src_y;
    logic [3:0][3:0]   node_resp_dest_x;
    logic [3:0][3:0]   node_resp_dest_y;
    logic [3:0][31:0]  node_resp_rdata;
    logic [3:0]        node_resp_error;
    logic [3:0]        node_protocol_error;

    // Routed response interface, delivered to the originating node.
    logic [3:0]        source_resp_valid;
    logic [3:0]        source_resp_ready;
    logic [3:0][3:0]   source_resp_src_x;
    logic [3:0][3:0]   source_resp_src_y;
    logic [3:0][3:0]   source_resp_dest_x;
    logic [3:0][3:0]   source_resp_dest_y;
    logic [3:0][31:0]  source_resp_rdata;
    logic [3:0]        source_resp_error;
    logic [3:0]        response_protocol_error;

    // ------------------------------------------------------------
    // Four cores and four independent memory adapters
    // ------------------------------------------------------------

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin : GEN_CORE

            rv32i_core #(
                .USE_MEMORY_HANDSHAKE(1'b1)
            ) u_core (
                .clk(clk),
                .rst_n(rst_n),

                .instruction_address(instruction_address[c]),
                .instruction_data(instruction_data[c]),

                .data_memory_read_enable(cpu_mem_read_enable[c]),
                .data_memory_write_enable(cpu_mem_write_enable[c]),
                .data_memory_funct3(cpu_mem_funct3[c]),
                .data_memory_address(cpu_mem_address[c]),
                .data_memory_write_data(cpu_mem_write_data[c]),
                .data_memory_read_data(cpu_mem_read_data[c]),

                .data_memory_request_ready(cpu_req_ready[c]),
                .data_memory_response_valid(cpu_resp_valid[c]),
                .data_memory_response_ready(cpu_resp_ready[c]),

                .retire_valid(retire_valid[c]),
                .retire_pc(retire_pc[c]),
                .retire_instruction(retire_instruction[c]),
                .retire_rd_we(retire_rd_we[c]),
                .retire_rd(retire_rd[c]),
                .retire_rd_data(retire_rd_data[c])
            );

            assign cpu_req_valid[c] =
                cpu_mem_read_enable[c] | cpu_mem_write_enable[c];

            assign memory_request_active[c] =
                adapter_noc_req_valid[c];

            assign memory_response_active[c] =
                adapter_noc_resp_valid[c];

            rv32i_noc_memory_adapter u_memory_adapter (
                .clk(clk),
                .rst_n(rst_n),

                .cpu_req_valid(cpu_req_valid[c]),
                .cpu_req_ready(cpu_req_ready[c]),
                .cpu_req_write(cpu_mem_write_enable[c]),
                .cpu_req_addr(cpu_mem_address[c]),
                .cpu_req_wdata(cpu_mem_write_data[c]),
                .cpu_req_funct3(cpu_mem_funct3[c]),

                .cpu_resp_valid(cpu_resp_valid[c]),
                .cpu_resp_ready(cpu_resp_ready[c]),
                .cpu_resp_rdata(cpu_mem_read_data[c]),

                .noc_req_valid(adapter_noc_req_valid[c]),
                .noc_req_ready(adapter_noc_req_ready[c]),
                .noc_req_write(adapter_noc_req_write[c]),
                .noc_req_addr(adapter_noc_req_addr[c]),
                .noc_req_wdata(adapter_noc_req_wdata[c]),
                .noc_req_funct3(adapter_noc_req_funct3[c]),

                .noc_resp_valid(adapter_noc_resp_valid[c]),
                .noc_resp_ready(adapter_noc_resp_ready[c]),
                .noc_resp_rdata(adapter_noc_resp_rdata[c])
            );

            // Each adapter connects to its matching fabric node.
            assign txn_valid[c]  = adapter_noc_req_valid[c];
            assign adapter_noc_req_ready[c] = txn_ready[c];

            assign txn_write[c]  = adapter_noc_req_write[c];
            assign txn_funct3[c] = adapter_noc_req_funct3[c];
            assign txn_addr[c]   = adapter_noc_req_addr[c];
            assign txn_wdata[c]  = adapter_noc_req_wdata[c];

            // Initial integration configuration:
            // route all four cores to the memory service at node (1,1).
            assign txn_dest_x[c] = 4'd1;
            assign txn_dest_y[c] = 4'd1;

            // The fabric returns responses to the original source node.
            assign adapter_noc_resp_valid[c] = source_resp_valid[c];
            assign adapter_noc_resp_rdata[c]  = source_resp_rdata[c];
            assign source_resp_ready[c]       = adapter_noc_resp_ready[c];

        end
    endgenerate

    // Always drain the optional local response-monitor buffers.
    assign node_resp_ready = 4'b1111;

    assign fabric_protocol_errors =
        node_protocol_error | response_protocol_error;

    // ------------------------------------------------------------
    // ONE shared 2x2 NoC fabric for all four CPU cores
    // ------------------------------------------------------------

    noc_memory_fabric_2x2 #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .MEM_BYTES(MEM_BYTES)
    ) u_shared_noc_fabric (
        .clk(clk),
        .rst_n(rst_n),

        .txn_valid(txn_valid),
        .txn_ready(txn_ready),
        .txn_dest_x(txn_dest_x),
        .txn_dest_y(txn_dest_y),
        .txn_write(txn_write),
        .txn_funct3(txn_funct3),
        .txn_addr(txn_addr),
        .txn_wdata(txn_wdata),

        .node_resp_valid(node_resp_valid),
        .node_resp_ready(node_resp_ready),
        .node_resp_src_x(node_resp_src_x),
        .node_resp_src_y(node_resp_src_y),
        .node_resp_dest_x(node_resp_dest_x),
        .node_resp_dest_y(node_resp_dest_y),
        .node_resp_rdata(node_resp_rdata),
        .node_resp_error(node_resp_error),
        .node_protocol_error(node_protocol_error),

        .source_resp_valid(source_resp_valid),
        .source_resp_ready(source_resp_ready),
        .source_resp_src_x(source_resp_src_x),
        .source_resp_src_y(source_resp_src_y),
        .source_resp_dest_x(source_resp_dest_x),
        .source_resp_dest_y(source_resp_dest_y),
        .source_resp_rdata(source_resp_rdata),
        .source_resp_error(source_resp_error),
        .response_protocol_error(response_protocol_error)
    );

endmodule
