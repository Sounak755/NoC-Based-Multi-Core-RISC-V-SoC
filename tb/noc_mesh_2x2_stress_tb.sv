
`timescale 1ns/1ps

module noc_mesh_2x2_stress_tb;

    reg clk, rst_n;

    reg [31:0] data_in_00, data_in_10, data_in_01, data_in_11;
    reg valid_in_00, valid_in_10, valid_in_01, valid_in_11;
    wire ready_in_00, ready_in_10, ready_in_01, ready_in_11;

    wire [31:0] data_out_00, data_out_10, data_out_01, data_out_11;
    wire valid_out_00, valid_out_10, valid_out_01, valid_out_11;
    reg ready_out_00, ready_out_10, ready_out_01, ready_out_11;

    integer count_a, count_b, count_c;

    noc_mesh_2x2 #(
        .DATA_WIDTH(32),
        .COORD_WIDTH(4),
        .FIFO_DEPTH(8)
    ) dut (
        .clk(clk), .rst_n(rst_n),

        .local_data_in_00(data_in_00),
        .local_valid_in_00(valid_in_00),
        .local_ready_in_00(ready_in_00),
        .local_data_out_00(data_out_00),
        .local_valid_out_00(valid_out_00),
        .local_ready_out_00(ready_out_00),

        .local_data_in_10(data_in_10),
        .local_valid_in_10(valid_in_10),
        .local_ready_in_10(ready_in_10),
        .local_data_out_10(data_out_10),
        .local_valid_out_10(valid_out_10),
        .local_ready_out_10(ready_out_10),

        .local_data_in_01(data_in_01),
        .local_valid_in_01(valid_in_01),
        .local_ready_in_01(ready_in_01),
        .local_data_out_01(data_out_01),
        .local_valid_out_01(valid_out_01),
        .local_ready_out_01(ready_out_01),

        .local_data_in_11(data_in_11),
        .local_valid_in_11(valid_in_11),
        .local_ready_in_11(ready_in_11),
        .local_data_out_11(data_out_11),
        .local_valid_out_11(valid_out_11),
        .local_ready_out_11(ready_out_11)
    );

    always #5 clk = ~clk;

    // Count only actual destination handshakes.
    always @(posedge clk) begin
        if (rst_n) begin
            if (valid_out_10 && ready_out_10) begin
                if (data_out_10 !== 32'h1000_A101)
                    $fatal(1, "Unexpected packet at node 10: %h",
                           data_out_10);

                count_a = count_a + 1;
                $display("Node 10 received packet A: %h", data_out_10);
            end

            if (valid_out_11 && ready_out_11) begin
                if (data_out_11 === 32'h1100_B202) begin
                    count_b = count_b + 1;
                    $display("Node 11 received packet B: %h", data_out_11);
                end
                else if (data_out_11 === 32'h1100_C303) begin
                    count_c = count_c + 1;
                    $display("Node 11 received packet C: %h", data_out_11);
                end
                else begin
                    $fatal(1, "Unexpected packet at node 11: %h",
                           data_out_11);
                end
            end
        end
    end

    task send_from_00;
        input [31:0] packet;
        integer timeout_count;
        begin
            @(negedge clk);
            data_in_00 = packet;
            valid_in_00 = 1'b1;
            timeout_count = 0;

            while (ready_in_00 !== 1'b1 && timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (ready_in_00 !== 1'b1)
                $fatal(1, "Timeout accepting packet at node 00");

            @(posedge clk);
            @(negedge clk);
            valid_in_00 = 1'b0;
        end
    endtask

    task send_from_01;
        input [31:0] packet;
        integer timeout_count;
        begin
            @(negedge clk);
            data_in_01 = packet;
            valid_in_01 = 1'b1;
            timeout_count = 0;

            while (ready_in_01 !== 1'b1 && timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (ready_in_01 !== 1'b1)
                $fatal(1, "Timeout accepting packet at node 01");

            @(posedge clk);
            @(negedge clk);
            valid_in_01 = 1'b0;
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;

        data_in_00 = 0;
        data_in_10 = 0;
        data_in_01 = 0;
        data_in_11 = 0;

        valid_in_00 = 0;
        valid_in_10 = 0;
        valid_in_01 = 0;
        valid_in_11 = 0;

        ready_out_00 = 1;
        ready_out_10 = 1;
        ready_out_01 = 1;
        ready_out_11 = 1;

        count_a = 0;
        count_b = 0;
        count_c = 0;

        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        // TEST 1: Two independent flows operate simultaneously.
        $display("");
        $display("TEST 1: Simultaneous traffic on independent routes");

        fork
            send_from_00(32'h1000_A101); // node 00 -> node 10
            send_from_01(32'h1100_B202); // node 01 -> node 11
        join

        begin : wait_for_first_two
            integer t;
            t = 0;
            while ((count_a < 1 || count_b < 1) && t < 100) begin
                @(negedge clk);
                t = t + 1;
            end
            if (count_a != 1 || count_b != 1)
                $fatal(1, "Simultaneous traffic failed: A=%0d B=%0d",
                       count_a, count_b);
        end

        repeat (5) @(negedge clk);
        if (count_a != 1 || count_b != 1)
            $fatal(1, "Duplicate detected in simultaneous traffic");

        $display("PASS: Both independent flows delivered exactly once");

        // TEST 2: Block node 11 and check packet stability.
        $display("");
        $display("TEST 2: Multi-hop backpressure to node 11");

        ready_out_11 = 0;
        send_from_00(32'h1100_C303);

        begin : wait_for_blocked_packet
            integer t;
            t = 0;

            while (valid_out_11 !== 1'b1 && t < 100) begin
                @(negedge clk);
                t = t + 1;
            end

            if (valid_out_11 !== 1'b1)
                $fatal(1, "Timeout: packet never reached blocked node 11");

            if (data_out_11 !== 32'h1100_C303)
                $fatal(1, "Incorrect blocked packet: %h", data_out_11);

            $display("PASS: Packet reached node 11 while blocked");

            repeat (4) begin
                @(negedge clk);

                if (valid_out_11 !== 1'b1)
                    $fatal(1, "Valid dropped during backpressure");

                if (data_out_11 !== 32'h1100_C303)
                    $fatal(1, "Packet changed during backpressure");
            end

            if (count_c != 0)
                $fatal(1, "Blocked packet transferred before ready");

            $display("PASS: Valid and data stayed stable while blocked");

            ready_out_11 = 1;
        end

        begin : wait_for_final_delivery
            integer t;
            t = 0;
            while (count_c < 1 && t < 100) begin
                @(negedge clk);
                t = t + 1;
            end

            if (count_c != 1)
                $fatal(1, "Packet did not transfer after ready asserted");
        end

        repeat (5) @(negedge clk);

        if (count_a != 1 || count_b != 1 || count_c != 1)
            $fatal(1, "Loss or duplicate detected: A=%0d B=%0d C=%0d",
                   count_a, count_b, count_c);

        $display("PASS: Blocked packet transferred exactly once after ready");
        $display("");
        $display("ALL MESH STRESS TESTS PASSED");
        $display("Packets delivered: A=%0d B=%0d C=%0d",
                 count_a, count_b, count_c);

        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "GLOBAL TEST TIMEOUT");
    end

endmodule
