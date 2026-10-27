
`timescale 1ns/1ps

module sync_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 8
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,

    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,

    output logic                  full,
    output logic                  empty
);

    localparam int ADDR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;
    logic [COUNT_WIDTH-1:0] count;

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    // Combinational read: output shows the current head entry.
    // Data is meaningful when empty == 0.
    assign rd_data = mem[rd_ptr];

    // Advance and wrap a pointer at DEPTH, including non-powers of two.
    function automatic logic [ADDR_WIDTH-1:0] next_ptr(
        input logic [ADDR_WIDTH-1:0] ptr
    );
        if (ptr == DEPTH - 1)
            next_ptr = '0;
        else
            next_ptr = ptr + 1'b1;
    endfunction

    // Synchronous state updates, active-low reset.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            // Accept writes only when not full, unless a read
            // happens on the same cycle and frees an entry.
            if (wr_en && (!full || (rd_en && !empty))) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= next_ptr(wr_ptr);
            end

            // Accept reads only when data is available.
            if (rd_en && !empty) begin
                rd_ptr <= next_ptr(rd_ptr);
            end

            // Count changes only when exactly one operation succeeds.
            case ({
                wr_en && (!full || (rd_en && !empty)),
                rd_en && !empty
            })
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

    initial begin
        if (DATA_WIDTH < 1)
            $error("DATA_WIDTH must be at least 1");
        if (DEPTH < 1)
            $error("DEPTH must be at least 1");
    end

endmodule
