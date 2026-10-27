
`timescale 1ns/1ps

module arbiter_debug_tb;

    reg clk = 0;
    reg rst_n = 0;
    reg [4:0] req = 0;
    reg advance = 0;
    wire [4:0] grant;

    round_robin_arbiter #(.N(5)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .advance(advance),
        .grant(grant)
    );

    always #5 clk = ~clk;

    initial begin
        $monitor("time=%0t rst_n=%b req=%b grant=%b",
                 $time, rst_n, req, grant);

        repeat (2) @(negedge clk);
        rst_n = 1;
        req = 5'b00100;

        #2;
        if (grant !== 5'b00100)
            $fatal(1, "Arbiter test failed");

        $display("ARBITER TEST PASSED");
        $finish;
    end

endmodule
