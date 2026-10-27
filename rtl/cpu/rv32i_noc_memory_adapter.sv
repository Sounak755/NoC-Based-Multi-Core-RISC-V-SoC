
module rv32i_noc_memory_adapter (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        cpu_req_valid,
    output logic        cpu_req_ready,
    input  logic        cpu_req_write,
    input  logic [31:0] cpu_req_addr,
    input  logic [31:0] cpu_req_wdata,
    input  logic [2:0]  cpu_req_funct3,

    output logic        cpu_resp_valid,
    input  logic        cpu_resp_ready,
    output logic [31:0] cpu_resp_rdata,

    output logic        noc_req_valid,
    input  logic        noc_req_ready,
    output logic        noc_req_write,
    output logic [31:0] noc_req_addr,
    output logic [31:0] noc_req_wdata,
    output logic [2:0]  noc_req_funct3,

    input  logic        noc_resp_valid,
    output logic        noc_resp_ready,
    input  logic [31:0] noc_resp_rdata
);

    typedef enum logic [1:0] {
        IDLE,
        SEND_REQUEST,
        WAIT_RESPONSE,
        RETURN_RESPONSE
    } state_t;

    state_t state;

    logic        saved_write;
    logic [31:0] saved_addr;
    logic [31:0] saved_wdata;
    logic [2:0]  saved_funct3;
    logic [31:0] saved_rdata;

    assign cpu_req_ready = (state == IDLE) && rst_n;

    assign noc_req_valid  = (state == SEND_REQUEST);
    assign noc_req_write  = saved_write;
    assign noc_req_addr   = saved_addr;
    assign noc_req_wdata  = saved_wdata;
    assign noc_req_funct3 = saved_funct3;

    assign noc_resp_ready = (state == WAIT_RESPONSE);

    assign cpu_resp_valid = (state == RETURN_RESPONSE);
    assign cpu_resp_rdata = saved_rdata;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state        <= IDLE;
            saved_write  <= 1'b0;
            saved_addr   <= 32'b0;
            saved_wdata  <= 32'b0;
            saved_funct3 <= 3'b0;
            saved_rdata  <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_req_valid && cpu_req_ready) begin
                        saved_write  <= cpu_req_write;
                        saved_addr   <= cpu_req_addr;
                        saved_wdata  <= cpu_req_wdata;
                        saved_funct3 <= cpu_req_funct3;
                        state        <= SEND_REQUEST;
                    end
                end

                SEND_REQUEST: begin
                    if (noc_req_valid && noc_req_ready)
                        state <= WAIT_RESPONSE;
                end

                WAIT_RESPONSE: begin
                    if (noc_resp_valid && noc_resp_ready) begin
                        saved_rdata <= noc_resp_rdata;
                        state       <= RETURN_RESPONSE;
                    end
                end

                RETURN_RESPONSE: begin
                    if (cpu_resp_valid && cpu_resp_ready)
                        state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
