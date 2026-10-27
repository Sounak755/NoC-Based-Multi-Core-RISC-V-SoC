
`timescale 1ns/1ps

module noc_mesh_2x2_contention_tb;

    reg clk, rst_n;

    reg [31:0] data_in_00, data_in_10, data_in_01, data_in_11;
    reg valid_in_00, valid_in_10, valid_in_01, valid_in_11;
    wire ready_in_00, ready_in_10, ready_in_01, ready_in_11;

    wire [31:0] data_out_00, data_out_10, data_out_01, data_out_11;
    wire valid_out_00, valid_out_10, valid_out_01, valid_out_11;
    reg ready_out_00, ready_out_10, ready_out_01, ready_out_11;

    integer count_a, count_b;
    integer cycle_count;

    integer accept_cycle_a, accept_cycle_b;
    integer latency_a, latency_b;
    integer latency_sum;
    integer min_latency, max_latency;

    integer first_accept_cycle;
    integer last_delivery_cycle;
    integer total_delivered;
    integer measurement_cycles;

    reg accepted_a, accepted_b;
    reg seen_a, seen_b;

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

    // Count cycles and measure actual ready/valid handshakes.
    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count = 0;
        end else begin
            cycle_count = cycle_count + 1;

            // Source acceptance: node 00, packet A.
            if (valid_in_00 && ready_in_00 &&
                data_in_00 == 32'h0100_A101) begin

                if (accepted_a)
                    $fatal(1, "Packet A accepted more than once");

                accepted_a = 1;
                accept_cycle_a = cycle_count;

                if (first_accept_cycle == 0)
                    first_accept_cycle = cycle_count;

                $display(
                    "[ACCEPT] A cycle=%0d packet=%h",
                    cycle_count, data_in_00
                );
            end

            // Source acceptance: node 10, packet B.
            if (valid_in_10 && ready_in_10 &&
                data_in_10 == 32'h0100_B202) begin

                if (accepted_b)
                    $fatal(1, "Packet B accepted more than once");

                accepted_b = 1;
                accept_cycle_b = cycle_count;

                if (first_accept_cycle == 0 ||
                    cycle_count < first_accept_cycle)
                    first_accept_cycle = cycle_count;

                $display(
                    "[ACCEPT] B cycle=%0d packet=%h",
                    cycle_count, data_in_10
                );
            end

            // Destination delivery: node 01.
            if (valid_out_01 && ready_out_01) begin
                case (data_out_01)

                    32'h0100_A101: begin
                        if (!accepted_a)
                            $fatal(1,
                                "Packet A delivered before acceptance");

                        if (seen_a)
                            $fatal(1, "Packet A duplicated");

                        seen_a = 1;
                        count_a = count_a + 1;

                        latency_a = cycle_count - accept_cycle_a;

                        if (latency_a < 0)
                            $fatal(1, "Invalid latency for packet A");

                        total_delivered = total_delivered + 1;
                        last_delivery_cycle = cycle_count;

                        $display(
                            "[DELIVER] A cycle=%0d latency=%0d cycles (%0d ns)",
                            cycle_count, latency_a, latency_a * 10
                        );
                    end

                    32'h0100_B202: begin
                        if (!accepted_b)
                            $fatal(1,
                                "Packet B delivered before acceptance");

                        if (seen_b)
                            $fatal(1, "Packet B duplicated");

                        seen_b = 1;
                        count_b = count_b + 1;

                        latency_b = cycle_count - accept_cycle_b;

                        if (latency_b < 0)
                            $fatal(1, "Invalid latency for packet B");

                        total_delivered = total_delivered + 1;
                        last_delivery_cycle = cycle_count;

                        $display(
                            "[DELIVER] B cycle=%0d latency=%0d cycles (%0d ns)",
                            cycle_count, latency_b, latency_b * 10
                        );
                    end

                    default:
                        $fatal(1,
                            "Unexpected packet at node 01: %h",
                            data_out_01);
                endcase
            end
        end
    end

    task send_from_00;
        input [31:0] packet;
        integer t;
        begin
            @(negedge clk);
            data_in_00 = packet;
            valid_in_00 = 1;
            t = 0;

            // Hold valid until a real handshake occurs.
            while (ready_in_00 !== 1'b1 && t < 100) begin
                @(negedge clk);
                t = t + 1;
            end

            if (ready_in_00 !== 1'b1)
                $fatal(1,
                    "Timeout accepting packet A at node 00");

            @(posedge clk);
            @(negedge clk);
            valid_in_00 = 0;
        end
    endtask

    task send_from_10;
        input [31:0] packet;
        integer t;
        begin
            @(negedge clk);
            data_in_10 = packet;
            valid_in_10 = 1;
            t = 0;

            // Hold valid until a real handshake occurs.
            while (ready_in_10 !== 1'b1 && t < 100) begin
                @(negedge clk);
                t = t + 1;
            end

            if (ready_in_10 !== 1'b1)
                $fatal(1,
                    "Timeout accepting packet B at node 10");

            @(posedge clk);
            @(negedge clk);
            valid_in_10 = 0;
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
        cycle_count = 0;

        accept_cycle_a = 0;
        accept_cycle_b = 0;
        latency_a = 0;
        latency_b = 0;
        latency_sum = 0;
        min_latency = 0;
        max_latency = 0;

        first_accept_cycle = 0;
        last_delivery_cycle = 0;
        total_delivered = 0;
        measurement_cycles = 0;

        accepted_a = 0;
        accepted_b = 0;
        seen_a = 0;
        seen_b = 0;

        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        $display("");
        $display("==============================================");
        $display("  2x2 NoC CONTENTION + LATENCY BENCHMARK");
        $display("==============================================");
        $display("Packet A: node 00 -> node 01");
        $display("Packet B: node 10 -> node 01");
        $display("Clock period: 10 ns");

        fork
            send_from_00(32'h0100_A101);
            send_from_10(32'h0100_B202);
        join

        begin : wait_for_delivery
            integer t;
            t = 0;

            while ((count_a < 1 || count_b < 1) && t < 150) begin
                @(negedge clk);
                t = t + 1;
            end

            if (count_a != 1 || count_b != 1)
                $fatal(1,
                    "Contention failure: A=%0d B=%0d",
                    count_a, count_b);
        end

        repeat (8) @(negedge clk);

        if (count_a != 1 || count_b != 1)
            $fatal(1, "Packet loss or duplication detected");

        if (!accepted_a || !accepted_b)
            $fatal(1, "One or more packets were never accepted");

        if (!seen_a || !seen_b || total_delivered != 2)
            $fatal(1, "Not all packets delivered exactly once");

        latency_sum = latency_a + latency_b;

        if (latency_a < latency_b) begin
            min_latency = latency_a;
            max_latency = latency_b;
        end else begin
            min_latency = latency_b;
            max_latency = latency_a;
        end

        measurement_cycles =
            last_delivery_cycle - first_accept_cycle + 1;

        if (measurement_cycles <= 0)
            $fatal(1, "Invalid throughput measurement window");

        $display("");
        $display("========== CONTENTION RESULTS ==========");
        $display("Packet A accepted : cycle %0d", accept_cycle_a);
        $display("Packet A delivered: cycle %0d", accept_cycle_a + latency_a);
        $display("Packet A latency  : %0d cycles", latency_a);
        $display("Packet B accepted : cycle %0d", accept_cycle_b);
        $display("Packet B delivered: cycle %0d", accept_cycle_b + latency_b);
        $display("Packet B latency  : %0d cycles", latency_b);
        $display("-----------------------------------------");
        $display("Packets delivered : %0d", total_delivered);
        $display("Average latency   : %0d.%0d cycles",
                 latency_sum / 2,
                 ((latency_sum % 2) * 5));
        $display("Minimum latency   : %0d cycles", min_latency);
        $display("Maximum latency   : %0d cycles", max_latency);
        $display("Measurement window: %0d cycles", measurement_cycles);
        $display("Throughput        : %0d packets / %0d cycles",
                 total_delivered, measurement_cycles);
        $display("Throughput        : %.4f packets/cycle",
                 total_delivered * 1.0 / measurement_cycles);
        $display("=========================================");

        $display("");
        $display("PASS: Both contending packets reached node 01");
        $display("PASS: Both packets were delivered exactly once");
        $display("ALL MESH CONTENTION + LATENCY TESTS PASSED");

        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "GLOBAL TEST TIMEOUT");
    end

endmodule
