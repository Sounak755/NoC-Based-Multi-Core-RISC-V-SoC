
`timescale 1ns/1ps

module router_output_arbiter_tb;

    localparam int N = 5;

    logic clk;
    logic rst_n;
    logic [N-1:0] request;
    logic advance;
    logic [N-1:0] grant;

    router_output_arbiter #(.N(N)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .request(request),
        .advance(advance),
        .grant(grant)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/router_output_arbiter.vcd");
        $dumpvars(0, router_output_arbiter_tb);

        clk = 0;
        rst_n = 0;
        request = 0;
        advance = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;

        // All five inputs request the output.
        request = 5'b11111;
        #1;
        if (grant !== 5'b00001)
            $fatal(1, "FAIL: Expected requester 0 first");

        $display("PASS: Requester 0 granted first");

        // Downstream stalls: grant must remain unchanged.
        repeat (3) begin
            @(negedge clk);
            #1;
            if (grant !== 5'b00001)
                $fatal(1, "FAIL: Grant changed during stall");
        end

        $display("PASS: Grant stable during stall");

        // Accept the transfer from requester 0.
        @(negedge clk);
        advance = 1;

        @(posedge clk);
        #1;
        advance = 0;
        #1;

        if (grant !== 5'b00010)
            $fatal(1, "FAIL: Expected requester 1 next");

        $display("PASS: Priority advances to requester 1");

        // Accept requester 1.
        @(negedge clk);
        advance = 1;

        @(posedge clk);
        #1;
        advance = 0;
        #1;

        if (grant !== 5'b00100)
            $fatal(1, "FAIL: Expected requester 2 next");

        $display("PASS: Priority advances to requester 2");

        $display("ALL OUTPUT ARBITER TESTS PASSED");
        $finish;
    end

endmodule
