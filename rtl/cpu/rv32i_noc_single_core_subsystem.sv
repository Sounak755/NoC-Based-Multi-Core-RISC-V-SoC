
`timescale 1ns/1ps

module rv32i_noc_single_core_subsystem #(
    parameter integer CPU_NODE = 0,   // 0=00, 1=10, 2=01, 3=11
    parameter integer FIFO_DEPTH = 8,
    parameter integer MEM_BYTES = 1024
) (
    input  logic        clk,
    input  logic        rst_n,

    // Instruction interface: connect an instruction ROM or test program.
    output logic [31:0] instruction_address,
    input  logic [31:0] instruction_data,

    // Retirement trace
    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [31:0] retire_instruction,
    output logic        retire_rd_we,
    output logic [4:0]  retire_rd,
    output logic [31:0] retire_rd_data,

    // Debug/verification
    output logic        memory_request_active,
    output logic        memory_response_active,
    output logic [3:0]  fabric_protocol_errors
);

    localparam logic [3:0] CPU_X = (CPU_NODE == 1 || CPU_NODE == 3) ? 4'd1 : 4'd0;
    localparam logic [3:0] CPU_Y = (CPU_NODE == 2 || CPU_NODE == 3) ? 4'd1 : 4'd0;

    logic        core_mem_read;
    logic        core_mem_write;
    logic [2:0]  core_mem_funct3;
    logic [31:0] core_mem_addr;
    logic [31:0] core_mem_wdata;
    logic [31:0] core_mem_rdata;

    logic core_mem_req_ready;
    logic core_mem_resp_valid;
    logic core_mem_resp_ready;

    logic adapter_cpu_req_valid;
    logic adapter_cpu_req_ready;
    logic adapter_cpu_req_write;
    logic [31:0] adapter_cpu_req_addr;
    logic [31:0] adapter_cpu_req_wdata;
    logic [2:0] adapter_cpu_req_funct3;

    logic adapter_cpu_resp_valid;
    logic adapter_cpu_resp_ready;
    logic [31:0] adapter_cpu_resp_rdata;

    logic adapter_noc_req_valid;
    logic adapter_noc_req_ready;
    logic adapter_noc_req_write;
    logic [31:0] adapter_noc_req_addr;
    logic [31:0] adapter_noc_req_wdata;
    logic [2:0] adapter_noc_req_funct3;

    logic adapter_noc_resp_valid;
    logic adapter_noc_resp_ready;
    logic [31:0] adapter_noc_resp_rdata;

    logic [3:0] fabric_txn_valid;
    logic [3:0] fabric_txn_ready;
    logic [3:0][3:0] fabric_txn_dest_x;
    logic [3:0][3:0] fabric_txn_dest_y;
    logic [3:0] fabric_txn_write;
    logic [3:0][2:0] fabric_txn_funct3;
    logic [3:0][31:0] fabric_txn_addr;
    logic [3:0][31:0] fabric_txn_wdata;

    logic [3:0] node_resp_valid;
    logic [3:0] node_resp_ready;
    logic [3:0][3:0] node_resp_src_x;
    logic [3:0][3:0] node_resp_src_y;
    logic [3:0][3:0] node_resp_dest_x;
    logic [3:0][3:0] node_resp_dest_y;
    logic [3:0][31:0] node_resp_rdata;
    logic [3:0] node_resp_error;
    logic [3:0] node_protocol_error;

    logic [3:0] source_resp_valid;
    logic [3:0] source_resp_ready;
    logic [3:0][3:0] source_resp_src_x;
    logic [3:0][3:0] source_resp_src_y;
    logic [3:0][3:0] source_resp_dest_x;
    logic [3:0][3:0] source_resp_dest_y;
    logic [3:0][31:0] source_resp_rdata;
    logic [3:0] source_resp_error;
    logic [3:0] response_protocol_error;

    assign adapter_cpu_req_valid = core_mem_read || core_mem_write;
    assign adapter_cpu_resp_ready = core_mem_resp_ready;

    assign core_mem_rdata = adapter_cpu_resp_rdata;
    assign core_mem_req_ready = adapter_cpu_req_ready;
    assign core_mem_resp_valid = adapter_cpu_resp_valid;

    assign memory_request_active = adapter_noc_req_valid;
    assign memory_response_active = adapter_noc_resp_valid;

    // ------------------------------------------------------------
    // RV32I core with memory handshaking enabled
    // ------------------------------------------------------------
    rv32i_core #(
        .USE_MEMORY_HANDSHAKE(1'b1)
    ) cpu (
        .clk(clk),
        .rst_n(rst_n),

        .instruction_address(instruction_address),
        .instruction_data(instruction_data),

        .data_memory_read_enable(core_mem_read),
        .data_memory_write_enable(core_mem_write),
        .data_memory_funct3(core_mem_funct3),
        .data_memory_address(core_mem_addr),
        .data_memory_write_data(core_mem_wdata),
        .data_memory_read_data(core_mem_rdata),

        .data_memory_request_ready(core_mem_req_ready),
        .data_memory_response_valid(core_mem_resp_valid),
        .data_memory_response_ready(core_mem_resp_ready),

        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_instruction(retire_instruction),
        .retire_rd_we(retire_rd_we),
        .retire_rd(retire_rd),
        .retire_rd_data(retire_rd_data)
    );

    // ------------------------------------------------------------
    // CPU-to-NoC transaction adapter
    // ------------------------------------------------------------
    rv32i_noc_memory_adapter memory_adapter (
        .clk(clk),
        .rst_n(rst_n),

        .cpu_req_valid(adapter_cpu_req_valid),
        .cpu_req_ready(adapter_cpu_req_ready),
        .cpu_req_write(core_mem_write),
        .cpu_req_addr(core_mem_addr),
        .cpu_req_wdata(core_mem_wdata),
        .cpu_req_funct3(core_mem_funct3),

        .cpu_resp_valid(adapter_cpu_resp_valid),
        .cpu_resp_ready(adapter_cpu_resp_ready),
        .cpu_resp_rdata(adapter_cpu_resp_rdata),

        .noc_req_valid(adapter_noc_req_valid),
        .noc_req_ready(adapter_noc_req_ready),
        .noc_req_write(adapter_noc_req_write),
        .noc_req_addr(adapter_noc_req_addr),
        .noc_req_wdata(adapter_noc_req_wdata),
        .noc_req_funct3(adapter_noc_req_funct3),

        .noc_resp_valid(adapter_noc_resp_valid),
        .noc_resp_ready(adapter_noc_resp_ready),
        .noc_resp_rdata(adapter_noc_resp_rdata)
    );

    // ------------------------------------------------------------
    // Map the CPU transaction onto its selected mesh node.
    // Other nodes' transaction inputs are held inactive.
    // ------------------------------------------------------------
    always @(*) begin
        fabric_txn_valid = 4'b0000;
        fabric_txn_dest_x = '0;
        fabric_txn_dest_y = '0;
        fabric_txn_write = '0;
        fabric_txn_funct3 = '0;
        fabric_txn_addr = '0;
        fabric_txn_wdata = '0;

        fabric_txn_valid[CPU_NODE] = adapter_noc_req_valid;
        fabric_txn_dest_x[CPU_NODE] = 4'd1;
        fabric_txn_dest_y[CPU_NODE] = 4'd1;
        fabric_txn_write[CPU_NODE] = adapter_noc_req_write;
        fabric_txn_funct3[CPU_NODE] = adapter_noc_req_funct3;
        fabric_txn_addr[CPU_NODE] = adapter_noc_req_addr;
        fabric_txn_wdata[CPU_NODE] = adapter_noc_req_wdata;
    end

    assign adapter_noc_req_ready = fabric_txn_ready[CPU_NODE];

    // Always drain local observer responses; the CPU uses the routed
    // source response interface, not the destination-local monitor.
    assign node_resp_ready = 4'b1111;

    always @(*) begin
        source_resp_ready = 4'b0000;
        source_resp_ready[CPU_NODE] = adapter_noc_resp_ready;
    end

    assign adapter_noc_resp_valid = source_resp_valid[CPU_NODE];
    assign adapter_noc_resp_rdata = source_resp_rdata[CPU_NODE];

    assign fabric_protocol_errors =
        node_protocol_error | response_protocol_error;

    // ------------------------------------------------------------
    // Complete 2x2 mesh plus four local memory services
    // ------------------------------------------------------------
    noc_memory_fabric_2x2 #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .MEM_BYTES(MEM_BYTES)
    ) memory_fabric (
        .clk(clk),
        .rst_n(rst_n),

        .txn_valid(fabric_txn_valid),
        .txn_ready(fabric_txn_ready),
        .txn_dest_x(fabric_txn_dest_x),
        .txn_dest_y(fabric_txn_dest_y),
        .txn_write(fabric_txn_write),
        .txn_funct3(fabric_txn_funct3),
        .txn_addr(fabric_txn_addr),
        .txn_wdata(fabric_txn_wdata),

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

    initial begin
        if (CPU_NODE < 0 || CPU_NODE > 3) begin
            $error("CPU_NODE must be 0, 1, 2, or 3");
        end
    end

endmodule
