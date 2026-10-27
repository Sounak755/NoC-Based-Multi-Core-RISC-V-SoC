
`timescale 1ns/1ps

module noc_memory_endpoint #(
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

    // Response output
    output logic        resp_valid,
    input  logic        resp_ready,
    output logic [31:0] resp_rdata,
    output logic        resp_error
);

    logic [7:0] mem [0:MEM_BYTES-1];

    logic [31:0] saved_rdata;
    logic        saved_error;
    logic        response_pending;

    integer i;
    integer byte_addr;

    logic [31:0] aligned_word;
    logic [31:0] load_value;
    logic [31:0] write_value;
    logic [3:0]  write_mask;
    logic        access_error;

    assign req_ready  = rst_n && !response_pending;
    assign resp_valid = response_pending;
    assign resp_rdata = saved_rdata;
    assign resp_error = saved_error;

    // Combinational read/validation and write-data preparation.
    always_comb begin
        byte_addr   = 0;
        aligned_word = 32'b0;
        load_value   = 32'b0;
        write_value  = req_wdata;
        write_mask   = 4'b0000;
        access_error = 1'b0;

        byte_addr = $unsigned(req_addr);

        if (byte_addr >= MEM_BYTES) begin
            access_error = 1'b1;
        end else begin
            // Validate the access size and alignment.
            case (req_funct3)
                3'b000, 3'b100: begin
                    write_mask = 4'b0001 << req_addr[1:0];
                    write_value = req_wdata << (8 * req_addr[1:0]);
                end

                3'b001, 3'b101: begin
                    if (req_addr[0] != 1'b0)
                        access_error = 1'b1;

                    if (req_addr[1:0] == 2'b00) begin
                        write_mask  = 4'b0011;
                        write_value = req_wdata;
                    end else if (req_addr[1:0] == 2'b10) begin
                        write_mask  = 4'b1100;
                        write_value = req_wdata << 16;
                    end else begin
                        access_error = 1'b1;
                    end
                end

                3'b010: begin
                    if (req_addr[1:0] != 2'b00)
                        access_error = 1'b1;

                    write_mask = 4'b1111;
                end

                default: begin
                    access_error = 1'b1;
                end
            endcase

            // Ensure the entire access fits within the memory.
            if (req_funct3 == 3'b001 || req_funct3 == 3'b101) begin
                if (byte_addr + 1 >= MEM_BYTES)
                    access_error = 1'b1;
            end

            if (req_funct3 == 3'b010) begin
                if (byte_addr + 3 >= MEM_BYTES)
                    access_error = 1'b1;
            end
        end

        // Read the aligned 32-bit word.
        if (!access_error && byte_addr + 3 < MEM_BYTES) begin
            aligned_word = {
                mem[(byte_addr & 32'hFFFFFFFC) + 3],
                mem[(byte_addr & 32'hFFFFFFFC) + 2],
                mem[(byte_addr & 32'hFFFFFFFC) + 1],
                mem[(byte_addr & 32'hFFFFFFFC)]
            };
        end

        // Extract and extend load values.
        case (req_funct3)
            3'b000: begin
                case (req_addr[1:0])
                    2'b00: load_value = {{24{aligned_word[7]}}, aligned_word[7:0]};
                    2'b01: load_value = {{24{aligned_word[15]}}, aligned_word[15:8]};
                    2'b10: load_value = {{24{aligned_word[23]}}, aligned_word[23:16]};
                    2'b11: load_value = {{24{aligned_word[31]}}, aligned_word[31:24]};
                endcase
            end

            3'b100: begin
                case (req_addr[1:0])
                    2'b00: load_value = {24'b0, aligned_word[7:0]};
                    2'b01: load_value = {24'b0, aligned_word[15:8]};
                    2'b10: load_value = {24'b0, aligned_word[23:16]};
                    2'b11: load_value = {24'b0, aligned_word[31:24]};
                endcase
            end

            3'b001: begin
                if (req_addr[1])
                    load_value = {{16{aligned_word[31]}}, aligned_word[31:16]};
                else
                    load_value = {{16{aligned_word[15]}}, aligned_word[15:0]};
            end

            3'b101: begin
                if (req_addr[1])
                    load_value = {16'b0, aligned_word[31:16]};
                else
                    load_value = {16'b0, aligned_word[15:0]};
            end

            3'b010: load_value = aligned_word;

            default: load_value = 32'b0;
        endcase
    end

    // One request is accepted at a time. The response remains valid
    // until the requester asserts resp_ready.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            response_pending <= 1'b0;
            saved_rdata      <= 32'b0;
            saved_error      <= 1'b0;

            for (i = 0; i < MEM_BYTES; i = i + 1)
                mem[i] <= 8'b0;
        end else begin
            if (response_pending && resp_ready)
                response_pending <= 1'b0;

            if (req_valid && req_ready) begin
                response_pending <= 1'b1;
                saved_error      <= access_error;

                if (access_error) begin
                    saved_rdata <= 32'b0;
                end else if (req_write) begin
                    saved_rdata <= 32'b0;

                    // Stores: SB, SH, SW.
                    case (req_funct3)
                        3'b000: begin
                            mem[byte_addr] <= req_wdata[7:0];
                        end

                        3'b001: begin
                            mem[byte_addr]     <= req_wdata[7:0];
                            mem[byte_addr + 1] <= req_wdata[15:8];
                        end

                        3'b010: begin
                            mem[byte_addr]     <= req_wdata[7:0];
                            mem[byte_addr + 1] <= req_wdata[15:8];
                            mem[byte_addr + 2] <= req_wdata[23:16];
                            mem[byte_addr + 3] <= req_wdata[31:24];
                        end

                        default: begin
                            saved_error <= 1'b1;
                        end
                    endcase
                end else begin
                    saved_rdata <= load_value;
                end
            end
        end
    end

endmodule
