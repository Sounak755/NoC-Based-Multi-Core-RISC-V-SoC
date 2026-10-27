
`timescale 1ns/1ps

module sync_fifo_tb;

    localparam int DATA_WIDTH = 32;
    localparam int DEPTH      = 8;

    logic clk;
    logic rst_n;
    logic wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic full;
    logic empty;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .full(full),
        .empty(empty)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic push(input logic [31:0] data);
        @(negedge clk);
        wr_en = 1'b1;
        wr_data = data;

        @(posedge clk);
        #1;
        wr_en = 1'b0;
    endtask

    task automatic pop(input logic [31:0] expected);
        @(negedge clk);

        if (empty)
            $fatal(1, "FAIL: FIFO unexpectedly empty");

        if (rd_data !== expected)
            $fatal(1, "FAIL: expected %h, got %h",
                   expected, rd_data);

        rd_en = 1'b1;
        @(posedge clk);
        #1;
        rd_en = 1'b0;
    endtask

    integer i;

    initial begin
        rst_n = 1'b0;
        wr_en = 1'b0;
        wr_data = '0;
        rd_en = 1'b0;

        $dumpfile("sim/sync_fifo.vcd");
        $dumpvars(0, sync_fifo_tb);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;

        if (!empty || full)
            $fatal(1, "FAIL: incorrect flags after reset");

        $display("PASS: reset");

        for (i = 0; i < DEPTH; i = i + 1)
            push(32'h1000 + i);

        if (!full || empty)
            $fatal(1, "FAIL: full flag not asserted");

        $display("PASS: FIFO fills to capacity");

        push(32'hDEAD_BEEF);

        if (!full)
            $fatal(1, "FAIL: FIFO full flag lost after overflow attempt");

        $display("PASS: overflow write rejected");

        for (i = 0; i < DEPTH; i = i + 1)
            pop(32'h1000 + i);

        if (!empty || full)
            $fatal(1, "FAIL: incorrect flags after draining");

        $display("PASS: FIFO ordering and empty flag");

        @(negedge clk);
        rd_en = 1'b1;
        @(posedge clk);
        #1;
        rd_en = 1'b0;

        if (!empty)
            $fatal(1, "FAIL: empty read changed FIFO count");

        $display("PASS: empty read rejected");
        $display("ALL FIFO TESTS PASSED");

        #10;
        $finish;
    end

endmodule
