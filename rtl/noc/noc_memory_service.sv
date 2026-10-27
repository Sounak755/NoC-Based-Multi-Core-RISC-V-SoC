
`timescale 1ns/1ps

module noc_memory_service #(
    parameter logic [3:0] NODE_X = 4'd0,
    parameter logic [3:0] NODE_Y = 4'd0,
    parameter integer MEM_BYTES = 1024
) (
    input  logic        clk,
    input  logic        rst_n,

    // Decoded request input
    input  logic        req_valid,
    output logic        req_ready,
    input  logic        req_write,
    input  logic [2:0]  req_funct3,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_src_x,
    input  logic [3:0]  req_src_y,
    input  logic [3:0]  req_dest_x,
    input  logic [3:0]  req_dest_y,

    // Response transaction output
    output logic        resp_valid,
    input  logic        resp_ready,
    output logic [3:0]  resp_src_x,
    output logic [3:0]  resp_src_y,
    output logic [3:0]  resp_dest_x,
    output logic [3:0]  resp_dest_y,
    output logic [31:0] resp_rdata,
    output logic        resp_error
);

    typedef enum logic [1:0] {
        IDLE,
        ISSUE_MEMORY,
        WAIT_MEMORY,
        RETURN_RESPONSE
    } state_t;

    state_t state;

    logic        mem_req_valid;
    logic        mem_req_ready;
    logic        mem_resp_valid;
    logic        mem_resp_ready;
    logic        mem_req_write;
    logic [2:0]  mem_req_funct3;
    logic [31:0] mem_req_addr;
    logic [31:0] mem_req_wdata;
    logic [31:0] mem_resp_rdata;
    logic        mem_resp_error;

    logic [3:0]  saved_src_x;
    logic [3:0]  saved_src_y;
    logic [3:0]  saved_dest_x;
    logic [3:0]  saved_dest_y;

    logic [31:0] saved_rdata;
    logic        saved_error;

    // Saved request fields
    logic        req_write_saved;
    logic [2:0]  funct3_saved;
    logic [31:0] addr_saved;
    logic [31:0] wdata_saved;

    assign req_ready = (state == IDLE) && rst_n;

    assign mem_req_valid  = (state == ISSUE_MEMORY);
    assign mem_req_write  = req_write_saved;
    assign mem_req_funct3 = funct3_saved;
    assign mem_req_addr   = addr_saved;
    assign mem_req_wdata  = wdata_saved;

    assign mem_resp_ready = (state == WAIT_MEMORY);

    assign resp_valid  = (state == RETURN_RESPONSE);
    assign resp_src_x  = saved_src_x;
    assign resp_src_y  = saved_src_y;
    assign resp_dest_x = saved_dest_x;
    assign resp_dest_y = saved_dest_y;
    assign resp_rdata  = saved_rdata;
    assign resp_error  = saved_error;

    noc_memory_endpoint #(
        .MEM_BYTES(MEM_BYTES)
    ) memory (
        .clk(clk),
        .rst_n(rst_n),

        .req_valid(mem_req_valid),
        .req_ready(mem_req_ready),
        .req_write(mem_req_write),
        .req_funct3(mem_req_funct3),
        .req_addr(mem_req_addr),
        .req_wdata(mem_req_wdata),

        .resp_valid(mem_resp_valid),
        .resp_ready(mem_resp_ready),
        .resp_rdata(mem_resp_rdata),
        .resp_error(mem_resp_error)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state           <= IDLE;

            req_write_saved <= 1'b0;
            funct3_saved    <= 3'b0;
            addr_saved      <= 32'b0;
            wdata_saved     <= 32'b0;

            saved_src_x     <= 4'b0;
            saved_src_y     <= 4'b0;
            saved_dest_x    <= 4'b0;
            saved_dest_y    <= 4'b0;

            saved_rdata     <= 32'b0;
            saved_error     <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (req_valid && req_ready) begin
                        saved_src_x  <= req_src_x;
                        saved_src_y  <= req_src_y;
                        saved_dest_x <= req_dest_x;
                        saved_dest_y <= req_dest_y;

                        req_write_saved <= req_write;
                        funct3_saved    <= req_funct3;
                        addr_saved      <= req_addr;
                        wdata_saved     <= req_wdata;

                        if ((req_dest_x != NODE_X) ||
                            (req_dest_y != NODE_Y)) begin
                            saved_rdata <= 32'b0;
                            saved_error <= 1'b1;
                            state       <= RETURN_RESPONSE;
                        end else begin
                            state <= ISSUE_MEMORY;
                        end
                    end
                end

                ISSUE_MEMORY: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= WAIT_MEMORY;
                end

                WAIT_MEMORY: begin
                    if (mem_resp_valid && mem_resp_ready) begin
                        saved_rdata <= mem_resp_rdata;
                        saved_error <= mem_resp_error;
                        state       <= RETURN_RESPONSE;
                    end
                end

                RETURN_RESPONSE: begin
                    if (resp_valid && resp_ready)
                        state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
