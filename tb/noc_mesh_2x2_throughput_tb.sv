
`timescale 1ns/1ps

module noc_mesh_2x2_throughput_tb;

    parameter integer DATA_WIDTH = 32;
    parameter integer PACKETS_PER_SOURCE = 20;
    parameter integer TOTAL_PACKETS = 3 * PACKETS_PER_SOURCE;
    parameter integer MAX_WAIT_CYCLES = 10000;

    reg clk;
    reg rst_n;

    // Node 00
    reg  [DATA_WIDTH-1:0] data_in_00;
    reg                   valid_in_00;
    wire                  ready_in_00;
    wire [DATA_WIDTH-1:0] data_out_00;
    wire                  valid_out_00;
    reg                   ready_out_00;

    // Node 10
    reg  [DATA_WIDTH-1:0] data_in_10;
    reg                   valid_in_10;
    wire                  ready_in_10;
    wire [DATA_WIDTH-1:0] data_out_10;
    wire                  valid_out_10;
    reg                   ready_out_10;

    // Node 01
    reg  [DATA_WIDTH-1:0] data_in_01;
    reg                   valid_in_01;
    wire                  ready_in_01;
    wire [DATA_WIDTH-1:0] data_out_01;
    wire                  valid_out_01;
    reg                   ready_out_01;

    // Node 11 is the common destination
    wire [DATA_WIDTH-1:0] data_out_11;
    wire                  valid_out_11;
    reg                   ready_out_11;

    integer cycle_count;
    integer accepted_count;
    integer delivered_count;
    integer first_accept_cycle;
    integer last_delivery_cycle;
    integer latency_sum;
    integer min_latency;
    integer max_latency;
    integer measurement_cycles;
    integer watchdog;

    integer accept_cycle [0:TOTAL_PACKETS-1];
    reg accepted [0:TOTAL_PACKETS-1];
    reg delivered [0:TOTAL_PACKETS-1];

    integer i;
    integer idx;
    integer packet_latency;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    noc_mesh_2x2 #(
        .DATA_WIDTH(DATA_WIDTH)
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

        .local_data_in_11(),
        .local_valid_in_11(1'b0),
        .local_ready_in_11(),
        .local_data_out_11(data_out_11),
        .local_valid_out_11(valid_out_11),
        .local_ready_out_11(ready_out_11)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Packet format
    //
    // [31:16] destination coordinate encoding = 16'h1100
    // [15:8]  source tag
    // [7:0]   sequence number (1..PACKETS_PER_SOURCE)
    // ------------------------------------------------------------

    function [31:0] make_packet;
        input [7:0] source_tag;
        input integer sequence_number;
        begin
            make_packet = 32'h1100_0000
                        | (source_tag << 8)
                        | sequence_number;
        end
    endfunction

    // Map each unique packet to an array index.
    function integer packet_index;
        input [31:0] packet;
        integer sequence_number;
        begin
            sequence_number = packet[7:0];

            if ((packet[31:16] != 16'h1100) ||
                (sequence_number < 1) ||
                (sequence_number > PACKETS_PER_SOURCE)) begin
                packet_index = -1;
            end else begin
                case (packet[15:8])
                    8'h00:
                        packet_index = sequence_number - 1;

                    8'h10:
                        packet_index =
                            PACKETS_PER_SOURCE + sequence_number - 1;

                    8'h01:
                        packet_index =
                            (2 * PACKETS_PER_SOURCE)
                            + sequence_number - 1;

                    default:
                        packet_index = -1;
                endcase
            end
        end
    endfunction

    // ------------------------------------------------------------
    // Traffic source: node 00
    // Changes packet only after a real input handshake.
    // ------------------------------------------------------------

    task send_from_00;
        integer seq;
        integer wait_cycles;
        reg accepted_this_packet;
        begin
            @(negedge clk);
            valid_in_00 = 1'b1;
            data_in_00 = make_packet(8'h00, 1);

            for (seq = 1; seq <= PACKETS_PER_SOURCE; seq = seq + 1) begin
                accepted_this_packet = 1'b0;
                wait_cycles = 0;

                while (!accepted_this_packet) begin
                    @(posedge clk);

                    if (valid_in_00 && ready_in_00)
                        accepted_this_packet = 1'b1;

                    wait_cycles = wait_cycles + 1;

                    if (wait_cycles > MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout at source 00, packet %0d", seq);
                end

                @(negedge clk);

                if (seq < PACKETS_PER_SOURCE)
                    data_in_00 = make_packet(8'h00, seq + 1);
                else
                    valid_in_00 = 1'b0;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Traffic source: node 10
    // ------------------------------------------------------------

    task send_from_10;
        integer seq;
        integer wait_cycles;
        reg accepted_this_packet;
        begin
            @(negedge clk);
            valid_in_10 = 1'b1;
            data_in_10 = make_packet(8'h10, 1);

            for (seq = 1; seq <= PACKETS_PER_SOURCE; seq = seq + 1) begin
                accepted_this_packet = 1'b0;
                wait_cycles = 0;

                while (!accepted_this_packet) begin
                    @(posedge clk);

                    if (valid_in_10 && ready_in_10)
                        accepted_this_packet = 1'b1;

                    wait_cycles = wait_cycles + 1;

                    if (wait_cycles > MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout at source 10, packet %0d", seq);
                end

                @(negedge clk);

                if (seq < PACKETS_PER_SOURCE)
                    data_in_10 = make_packet(8'h10, seq + 1);
                else
                    valid_in_10 = 1'b0;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Traffic source: node 01
    // ------------------------------------------------------------

    task send_from_01;
        integer seq;
        integer wait_cycles;
        reg accepted_this_packet;
        begin
            @(negedge clk);
            valid_in_01 = 1'b1;
            data_in_01 = make_packet(8'h01, 1);

            for (seq = 1; seq <= PACKETS_PER_SOURCE; seq = seq + 1) begin
                accepted_this_packet = 1'b0;
                wait_cycles = 0;

                while (!accepted_this_packet) begin
                    @(posedge clk);

                    if (valid_in_01 && ready_in_01)
                        accepted_this_packet = 1'b1;

                    wait_cycles = wait_cycles + 1;

                    if (wait_cycles > MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout at source 01, packet %0d", seq);
                end

                @(negedge clk);

                if (seq < PACKETS_PER_SOURCE)
                    data_in_01 = make_packet(8'h01, seq + 1);
                else
                    valid_in_01 = 1'b0;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Measurement monitor
    // Counts only actual valid && ready handshakes.
    // ------------------------------------------------------------

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count = 0;
        end else begin
            cycle_count = cycle_count + 1;

            // Acceptance at node 00
            if (valid_in_00 && ready_in_00) begin
                idx = packet_index(data_in_00);

                if (idx < 0)
                    $fatal(1, "Invalid node 00 packet: %h", data_in_00);

                if (accepted[idx])
                    $fatal(1, "Duplicate acceptance: %h", data_in_00);

                accepted[idx] = 1'b1;
                accept_cycle[idx] = cycle_count;
                accepted_count = accepted_count + 1;

                if (accepted_count == 1)
                    first_accept_cycle = cycle_count;
            end

            // Acceptance at node 10
            if (valid_in_10 && ready_in_10) begin
                idx = packet_index(data_in_10);

                if (idx < 0)
                    $fatal(1, "Invalid node 10 packet: %h", data_in_10);

                if (accepted[idx])
                    $fatal(1, "Duplicate acceptance: %h", data_in_10);

                accepted[idx] = 1'b1;
                accept_cycle[idx] = cycle_count;
                accepted_count = accepted_count + 1;

                if (accepted_count == 1)
                    first_accept_cycle = cycle_count;
            end

            // Acceptance at node 01
            if (valid_in_01 && ready_in_01) begin
                idx = packet_index(data_in_01);

                if (idx < 0)
                    $fatal(1, "Invalid node 01 packet: %h", data_in_01);

                if (accepted[idx])
                    $fatal(1, "Duplicate acceptance: %h", data_in_01);

                accepted[idx] = 1'b1;
                accept_cycle[idx] = cycle_count;
                accepted_count = accepted_count + 1;

                if (accepted_count == 1)
                    first_accept_cycle = cycle_count;
            end

            // Delivery at destination node 11
            if (valid_out_11 && ready_out_11) begin
                idx = packet_index(data_out_11);

                if (idx < 0)
                    $fatal(1, "Unexpected packet at node 11: %h",
                           data_out_11);

                if (!accepted[idx])
                    $fatal(1, "Delivery before acceptance: %h",
                           data_out_11);

                if (delivered[idx])
                    $fatal(1, "Duplicate delivery: %h", data_out_11);

                delivered[idx] = 1'b1;
                delivered_count = delivered_count + 1;
                last_delivery_cycle = cycle_count;

                packet_latency = cycle_count - accept_cycle[idx];
                latency_sum = latency_sum + packet_latency;

                if (packet_latency < min_latency)
                    min_latency = packet_latency;

                if (packet_latency > max_latency)
                    max_latency = packet_latency;

                $display(
                    "DELIVER cycle=%0d packet=%h latency=%0d cycles",
                    cycle_count, data_out_11, packet_latency
                );
            end
        end
    end

    // ------------------------------------------------------------
    // Test sequence and final report
    // ------------------------------------------------------------

    initial begin
        rst_n = 1'b0;

        data_in_00 = 0;
        data_in_10 = 0;
        data_in_01 = 0;

        valid_in_00 = 1'b0;
        valid_in_10 = 1'b0;
        valid_in_01 = 1'b0;

        ready_out_00 = 1'b1;
        ready_out_10 = 1'b1;
        ready_out_01 = 1'b1;
        ready_out_11 = 1'b1;

        cycle_count = 0;
        accepted_count = 0;
        delivered_count = 0;
        first_accept_cycle = 0;
        last_delivery_cycle = 0;
        latency_sum = 0;
        min_latency = 2147483647;
        max_latency = 0;
        watchdog = 0;

        for (i = 0; i < TOTAL_PACKETS; i = i + 1) begin
            accept_cycle[i] = -1;
            accepted[i] = 1'b0;
            delivered[i] = 1'b0;
        end

        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        $display("");
        $display("==============================================");
        $display("    NoC 2x2 THROUGHPUT BENCHMARK");
        $display("==============================================");
        $display("Sources              : 00, 10, 01");
        $display("Destination          : 11");
        $display("Packets per source   : %0d", PACKETS_PER_SOURCE);
        $display("Expected total       : %0d", TOTAL_PACKETS);
        $display("");

        fork
            send_from_00();
            send_from_10();
            send_from_01();
        join

        // Allow all accepted packets to reach the destination.
        while (delivered_count < TOTAL_PACKETS) begin
            @(negedge clk);
            watchdog = watchdog + 1;

            if (watchdog > MAX_WAIT_CYCLES)
                $fatal(1,
                    "Delivery timeout: accepted=%0d delivered=%0d expected=%0d",
                    accepted_count, delivered_count, TOTAL_PACKETS);
        end

        #1;

        if (accepted_count != TOTAL_PACKETS)
            $fatal(1, "Acceptance mismatch: %0d of %0d",
                   accepted_count, TOTAL_PACKETS);

        if (delivered_count != TOTAL_PACKETS)
            $fatal(1, "Delivery mismatch: %0d of %0d",
                   delivered_count, TOTAL_PACKETS);

        for (i = 0; i < TOTAL_PACKETS; i = i + 1) begin
            if (!accepted[i])
                $fatal(1, "Packet index %0d was never accepted", i);

            if (!delivered[i])
                $fatal(1, "Packet index %0d was never delivered", i);
        end

        measurement_cycles =
            last_delivery_cycle - first_accept_cycle + 1;

        if (measurement_cycles <= 0)
            $fatal(1, "Invalid measurement window");

        $display("");
        $display("--------------- RESULTS ----------------------");
        $display("Packets accepted       : %0d", accepted_count);
        $display("Packets delivered      : %0d", delivered_count);
        $display("Packets lost           : %0d",
                 accepted_count - delivered_count);
        $display("Duplicate deliveries   : 0");
        $display("First acceptance cycle : %0d", first_accept_cycle);
        $display("Last delivery cycle    : %0d", last_delivery_cycle);
        $display("Measurement window     : %0d cycles", measurement_cycles);
        $display("Minimum latency        : %0d cycles", min_latency);
        $display("Maximum latency        : %0d cycles", max_latency);
        $display("Average latency        : %0.2f cycles",
                 1.0 * latency_sum / delivered_count);
        $display("Throughput             : %0.4f packets/cycle",
                 1.0 * delivered_count / measurement_cycles);
        $display("Clock period           : 10 ns");
        $display("Simulation clock rate  : 100 MHz");
        $display("----------------------------------------------");
        $display("THROUGHPUT BENCHMARK PASSED");
        $display("");

        $finish;
    end

endmodule
