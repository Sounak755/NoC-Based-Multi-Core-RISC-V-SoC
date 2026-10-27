
`timescale 1ns/1ps

module router_switch_allocator_tb;

    localparam integer PORTS = 5;
    localparam integer NORTH = 0;
    localparam integer SOUTH = 1;

    reg clk;
    reg rst_n;
    reg [PORTS*PORTS-1:0] req_by_input;
    reg [PORTS-1:0] advance;
    wire [PORTS*PORTS-1:0] grant_by_output;

    router_switch_allocator #(
        .PORTS(PORTS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_by_input(req_by_input),
        .advance(advance),
        .grant_by_output(grant_by_output)
    );

    always #5 clk = ~clk;

    function [PORTS-1:0] get_grant;
        input integer output_index;
        begin
            get_grant =
                grant_by_output[output_index*PORTS +: PORTS];
        end
    endfunction

    integer south_start_before;

    initial begin
        clk = 0;
        rst_n = 0;
        req_by_input = 0;
        advance = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;
        #1;

        // Input 2 requests both NORTH and SOUTH.
        req_by_input[2*PORTS + NORTH] = 1'b1;
        req_by_input[2*PORTS + SOUTH] = 1'b1;
        #1;

        // NORTH has lower output index, so it wins the conflict.
        if ((get_grant(NORTH) & 5'b00100) == 0)
            $fatal(1, "FAIL: NORTH should grant input 2");

        if ((get_grant(SOUTH) & 5'b00100) != 0)
            $fatal(1, "FAIL: SOUTH must not grant input 2");

        $display("PASS: Conflicting input is granted only once");

        // Record SOUTH's pointer before its masked grant is tested.
        south_start_before = dut.GEN_OUTPUT[SOUTH].arbiter_inst.rr_start;

        // SOUTH is not accepted because its grant is masked.
        advance[SOUTH] = 1'b1;
        @(negedge clk);
        #1;
        advance[SOUTH] = 1'b0;

        if (dut.GEN_OUTPUT[SOUTH].arbiter_inst.rr_start
            !== south_start_before)
            $fatal(1, "FAIL: SOUTH pointer advanced without acceptance");

        $display("PASS: Masked grant does not advance SOUTH pointer");
        $display("ALL MASKED-GRANT TESTS PASSED");

        $finish;
    end

    initial begin
        #200;
        $fatal(1, "FAIL: Simulation timeout");
    end

endmodule
