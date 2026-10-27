
`timescale 1ns/1ps

module noc_mesh_2x2_latency_tb;

    reg clk;
    reg rst_n;

    reg [31:0] data_in_00, data_in_10, data_in_01, data_in_11;
    reg valid_in_00, valid_in_10, valid_in_01, valid_in_11;
    wire ready_in_00, ready_in_10, ready_in_01, ready_in_11;

    wire [31:0] data_out_00, data_out_10, data_out_01, data_out_11;
    wire valid_out_00, valid_out_10, valid_out_01, valid_out_11;
    reg ready_out_00, ready_out_10, ready_out_01, ready_out_11;

    integer received_count;
    integer cycle_count;
    integer injection_cycle [0:2];
    integer latency_cycles [0:2];
    integer i;

    integer expected_node;
    reg [31:0] expected_packet;

    noc_mesh_2x2 #(
        .DATA_WIDTH(32),
        .COORD_WIDTH(4),
        .FIFO_DEPTH(8)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

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

    // Count active clock edges after reset.
    always @(posedge clk) begin
        if (!rst_n)
            cycle_count = 0;
        else
            cycle_count = cycle_count + 1;
    end

    // Monitor destination handshakes.
    // A transfer occurs when valid and ready are both high.
    always @(posedge clk) begin
        if (rst_n) begin
            if (valid_out_00 && ready_out_00)
                check_packet(0, data_out_00);

            if (valid_out_10 && ready_out_10)
                check_packet(1, data_out_10);

            if (valid_out_01 && ready_out_01)
                check_packet(2, data_out_01);

            if (valid_out_11 && ready_out_11)
                check_packet(3, data_out_11);
        end
    end

    task check_packet;
        input integer node;
        input [31:0] packet;
        integer packet_index;
        begin
            if (node != expected_node) begin
                $display("FAIL: Expected node %0d, got node %0d",
                         expected_node, node);
                $fatal(1, "Incorrect destination");
            end

            if (packet !== expected_packet) begin
                $display("FAIL: Expected packet %h, got %h",
                         expected_packet, packet);
                $fatal(1, "Packet data mismatch");
            end

            case (packet)
                32'h1100_00A1: packet_index = 0;
                32'h0000_00B2: packet_index = 1;
                32'h1000_00C3: packet_index = 2;
                default: begin
                    $fatal(1, "Unexpected packet received: %h", packet);
                    packet_index = 0;
                end
            endcase

            latency_cycles[packet_index] =
                cycle_count - injection_cycle[packet_index];

            $display(
                "LATENCY packet=%h cycles=%0d time=%0d ns",
                packet,
                latency_cycles[packet_index],
                latency_cycles[packet_index] * 10
            );

            received_count = received_count + 1;

            if (received_count > 3)
                $fatal(1, "Duplicate or unexpected packet transfer");

            $display("TRANSFER %0d: node=%0d packet=%h",
                     received_count, node, packet);
        end
    endtask

    task send_packet;
        input integer source;
        input [31:0] packet;
        integer packet_index;
        begin
            case (packet)
                32'h1100_00A1: packet_index = 0;
                32'h0000_00B2: packet_index = 1;
                32'h1000_00C3: packet_index = 2;
                default: begin
                    $fatal(1, "Unknown packet injected: %h", packet);
                    packet_index = 0;
                end
            endcase

            @(negedge clk);

            case (source)
                0: begin
                    data_in_00 = packet;
                    valid_in_00 = 1;
                end
                1: begin
                    data_in_10 = packet;
                    valid_in_10 = 1;
                end
                2: begin
                    data_in_01 = packet;
                    valid_in_01 = 1;
                end
                3: begin
                    data_in_11 = packet;
                    valid_in_11 = 1;
                end
                default: $fatal(1, "Invalid source node");
            endcase

            // Wait until the source can accept the packet.
            case (source)
                0: while (ready_in_00 !== 1'b1) @(negedge clk);
                1: while (ready_in_10 !== 1'b1) @(negedge clk);
                2: while (ready_in_01 !== 1'b1) @(negedge clk);
                3: while (ready_in_11 !== 1'b1) @(negedge clk);
            endcase

            // Record the injection edge, then release valid.
            @(posedge clk);
            injection_cycle[packet_index] = cycle_count;

            @(negedge clk);

            case (source)
                0: valid_in_00 = 0;
                1: valid_in_10 = 0;
                2: valid_in_01 = 0;
                3: valid_in_11 = 0;
            endcase
        end
    endtask

    task wait_for_count;
        input integer target_count;
        integer timeout_count;
        begin
            timeout_count = 0;

            while (received_count < target_count &&
                   timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (received_count < target_count)
                $fatal(1, "Timeout waiting for transfer %0d",
                       target_count);

            // Check for duplicate deliveries.
            repeat (5) @(negedge clk);

            if (received_count != target_count)
                $fatal(1, "Expected %0d transfers; observed %0d",
                       target_count, received_count);
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

        received_count = 0;
        cycle_count = 0;

        for (i = 0; i < 3; i = i + 1) begin
            injection_cycle[i] = 0;
            latency_cycles[i] = 0;
        end

        expected_node = 3;
        expected_packet = 32'h1100_00A1;

        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        $display("");
        $display("========================================");
        $display("  2x2 NoC LATENCY MEASUREMENT");
        $display("========================================");

        $display("");
        $display("TEST 1: Node 00 -> node 11");
        expected_node = 3;
        expected_packet = 32'h1100_00A1;
        send_packet(0, 32'h1100_00A1);
        wait_for_count(1);
        $display("PASS: Multi-hop routing 00 -> 11");

        $display("");
        $display("TEST 2: Node 11 -> node 00");
        expected_node = 0;
        expected_packet = 32'h0000_00B2;
        send_packet(3, 32'h0000_00B2);
        wait_for_count(2);
        $display("PASS: Multi-hop routing 11 -> 00");

        $display("");
        $display("TEST 3: Local delivery at node 10");
        expected_node = 1;
        expected_packet = 32'h1000_00C3;
        send_packet(1, 32'h1000_00C3);
        wait_for_count(3);
        $display("PASS: Local delivery at node 10");

        $display("");
        $display("========================================");
        $display("  LATENCY SUMMARY");
        $display("========================================");
        $display("Packet A (00 -> 11): %0d cycles, %0d ns",
                 latency_cycles[0], latency_cycles[0] * 10);
        $display("Packet B (11 -> 00): %0d cycles, %0d ns",
                 latency_cycles[1], latency_cycles[1] * 10);
        $display("Packet C (10 -> 10): %0d cycles, %0d ns",
                 latency_cycles[2], latency_cycles[2] * 10);
        $display("");
        $display("Clock period: 10 ns (100 MHz simulation clock)");
        $display("Total packets delivered: %0d", received_count);
        $display("ALL 2x2 MESH LATENCY TESTS PASSED");
        $display("");

        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "GLOBAL TEST TIMEOUT");
    end

endmodule
