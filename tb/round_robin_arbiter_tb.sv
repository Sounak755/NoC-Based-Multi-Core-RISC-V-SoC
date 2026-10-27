`timescale 1ns/1ps

module round_robin_arbiter_tb;

    localparam int N = 4;

    logic clk;
    logic rst_n;
    logic [N-1:0] req;
    logic advance;
    logic [N-1:0] grant;

    round_robin_arbiter #(.N(N)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .advance(advance),
        .grant(grant)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/round_robin_arbiter.vcd");
        $dumpvars(0, round_robin_arbiter_tb);

        clk = 0;
        rst_n = 0;
        req = 0;
        advance = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;

        // All requesters compete: requester 0 wins after reset.
        req = 4'b1111;
        #1;
        if (grant !== 4'b0001)
            $fatal(1, "FAIL: Expected requester 0");

        $display("PASS: Requester 0 granted first");

        // Stall: priority must not advance.
        repeat (3) begin
            @(negedge clk);
            #1;
            if (grant !== 4'b0001)
                $fatal(1, "FAIL: Grant changed during stall");
        end

        $display("PASS: Grant remains stable during stall");

        // Accept requester 0's transfer.
        @(negedge clk);
        advance = 1;

        @(posedge clk);
        #1;
        advance = 0;

        // Next priority should go to requester 1.
        #1;
        if (grant !== 4'b0010)
            $fatal(1, "FAIL: Expected requester 1 after acceptance");

        $display("PASS: Priority advances after acceptance");

        // Accept requester 1.
        @(negedge clk);
        advance = 1;

        @(posedge clk);
        #1;
        advance = 0;

        if (grant !== 4'b0100)
            $fatal(1, "FAIL: Expected requester 2");

        $display("PASS: Round-robin rotation continues");

        $display("ALL ARBITER TESTS PASSED");
        $finish;
    end

endmodule