`timescale 1ns/1ps

module router_input_buffer_bank_tb;

    localparam int DATA_WIDTH = 32;
    localparam int DEPTH = 4;

    logic clk, rst_n;

    logic [31:0] north_data_in, south_data_in;
    logic [31:0] east_data_in, west_data_in, local_data_in;

    logic north_valid_in, south_valid_in;
    logic east_valid_in, west_valid_in, local_valid_in;

    logic north_ready_in, south_ready_in;
    logic east_ready_in, west_ready_in, local_ready_in;

    logic [31:0] north_data_out, south_data_out;
    logic [31:0] east_data_out, west_data_out, local_data_out;

    logic north_valid_out, south_valid_out;
    logic east_valid_out, west_valid_out, local_valid_out;

    logic north_ready_out, south_ready_out;
    logic east_ready_out, west_ready_out, local_ready_out;

    router_input_buffer_bank #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk), .rst_n(rst_n),

        .north_data_in(north_data_in),
        .north_valid_in(north_valid_in),
        .north_ready_in(north_ready_in),
        .north_data_out(north_data_out),
        .north_valid_out(north_valid_out),
        .north_ready_out(north_ready_out),

        .south_data_in(south_data_in),
        .south_valid_in(south_valid_in),
        .south_ready_in(south_ready_in),
        .south_data_out(south_data_out),
        .south_valid_out(south_valid_out),
        .south_ready_out(south_ready_out),

        .east_data_in(east_data_in),
        .east_valid_in(east_valid_in),
        .east_ready_in(east_ready_in),
        .east_data_out(east_data_out),
        .east_valid_out(east_valid_out),
        .east_ready_out(east_ready_out),

        .west_data_in(west_data_in),
        .west_valid_in(west_valid_in),
        .west_ready_in(west_ready_in),
        .west_data_out(west_data_out),
        .west_valid_out(west_valid_out),
        .west_ready_out(west_ready_out),

        .local_data_in(local_data_in),
        .local_valid_in(local_valid_in),
        .local_ready_in(local_ready_in),
        .local_data_out(local_data_out),
        .local_valid_out(local_valid_out),
        .local_ready_out(local_ready_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/router_input_buffer_bank.vcd");
        $dumpvars(0, router_input_buffer_bank_tb);

        clk = 0;
        rst_n = 0;

        north_data_in = 0;
        south_data_in = 0;
        east_data_in = 0;
        west_data_in = 0;
        local_data_in = 0;

        north_valid_in = 0;
        south_valid_in = 0;
        east_valid_in = 0;
        west_valid_in = 0;
        local_valid_in = 0;

        north_ready_out = 0;
        south_ready_out = 0;
        east_ready_out = 0;
        west_ready_out = 0;
        local_ready_out = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // All five buffers should start empty.
        if ({north_valid_out, south_valid_out,
             east_valid_out, west_valid_out,
             local_valid_out} !== 5'b00000)
            $fatal(1, "FAIL: One or more buffers are not empty");

        $display("PASS: All five buffers initially empty");

        // Present one packet to every input simultaneously.
        north_data_in = 32'h1111_0001;
        south_data_in = 32'h2222_0002;
        east_data_in  = 32'h3333_0003;
        west_data_in  = 32'h4444_0004;
        local_data_in = 32'h5555_0005;

        north_valid_in = 1;
        south_valid_in = 1;
        east_valid_in  = 1;
        west_valid_in  = 1;
        local_valid_in = 1;

        #1;
        if ({north_ready_in, south_ready_in,
             east_ready_in, west_ready_in,
             local_ready_in} !== 5'b11111)
            $fatal(1, "FAIL: Not all buffers ready");

        @(posedge clk);
        @(negedge clk);

        north_valid_in = 0;
        south_valid_in = 0;
        east_valid_in  = 0;
        west_valid_in  = 0;
        local_valid_in = 0;

        // Check that each FIFO retained its own packet.
        if (north_data_out !== 32'h1111_0001 ||
            south_data_out !== 32'h2222_0002 ||
            east_data_out  !== 32'h3333_0003 ||
            west_data_out  !== 32'h4444_0004 ||
            local_data_out !== 32'h5555_0005)
            $fatal(1, "FAIL: Packet data incorrect");

        if ({north_valid_out, south_valid_out,
             east_valid_out, west_valid_out,
             local_valid_out} !== 5'b11111)
            $fatal(1, "FAIL: One or more packets missing");

        $display("PASS: All five buffers independently stored their packets");

        // Consume only the EAST packet.
        east_ready_out = 1;

        @(posedge clk);
        @(negedge clk);

        east_ready_out = 0;

        if (east_valid_out !== 1'b0)
            $fatal(1, "FAIL: EAST buffer should now be empty");

        if ({north_valid_out, south_valid_out,
             west_valid_out, local_valid_out} !== 4'b1111)
            $fatal(1, "FAIL: Consuming EAST affected another buffer");

        $display("PASS: EAST drained independently");
        $display("PASS: Other four buffers retained their packets");
        $display("ALL BUFFER BANK TESTS PASSED");

        $finish;
    end

endmodule