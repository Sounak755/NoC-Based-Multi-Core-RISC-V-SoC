
`timescale 1ns/1ps

module noc_router_fairness_tb;

    localparam integer DATA_WIDTH = 32;
    localparam integer COORD_WIDTH = 4;
    localparam integer FIFO_DEPTH = 8;
    localparam integer PACKETS_PER_INPUT = 16;
    localparam integer TOTAL_PACKETS = 2 * PACKETS_PER_INPUT;

    logic clk;
    logic rst_n;
    logic [3:0] router_x, router_y;

    logic [31:0] local_data_in;
    logic local_valid_in;
    wire local_ready_in;

    logic [31:0] north_data_in;
    logic north_valid_in;
    wire north_ready_in;

    logic [31:0] south_data_in;
    logic south_valid_in;
    wire south_ready_in;

    logic [31:0] east_data_in;
    logic east_valid_in;
    wire east_ready_in;

    logic [31:0] west_data_in;
    logic west_valid_in;
    wire west_ready_in;

    wire [31:0] local_data_out;
    wire local_valid_out;
    logic local_ready_out;

    wire [31:0] north_data_out;
    wire north_valid_out;
    logic north_ready_out;

    wire [31:0] south_data_out;
    wire south_valid_out;
    logic south_ready_out;

    wire [31:0] east_data_out;
    wire east_valid_out;
    logic east_ready_out;

    wire [31:0] west_data_out;
    wire west_valid_out;
    logic west_ready_out;

    integer local_sent;
    integer north_sent;

    integer local_received;
    integer north_received;
    integer total_received;

    integer consecutive_local;
    integer consecutive_north;
    integer max_consecutive_local;
    integer max_consecutive_north;

    logic [31:0] packet;

    noc_router #(
        .DATA_WIDTH(DATA_WIDTH),
        .COORD_WIDTH(COORD_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .router_x(router_x),
        .router_y(router_y),

        .local_data_in(local_data_in),
        .local_valid_in(local_valid_in),
        .local_ready_in(local_ready_in),

        .north_data_in(north_data_in),
        .north_valid_in(north_valid_in),
        .north_ready_in(north_ready_in),

        .south_data_in(south_data_in),
        .south_valid_in(south_valid_in),
        .south_ready_in(south_ready_in),

        .east_data_in(east_data_in),
        .east_valid_in(east_valid_in),
        .east_ready_in(east_ready_in),

        .west_data_in(west_data_in),
        .west_valid_in(west_valid_in),
        .west_ready_in(west_ready_in),

        .local_data_out(local_data_out),
        .local_valid_out(local_valid_out),
        .local_ready_out(local_ready_out),

        .north_data_out(north_data_out),
        .north_valid_out(north_valid_out),
        .north_ready_out(north_ready_out),

        .south_data_out(south_data_out),
        .south_valid_out(south_valid_out),
        .south_ready_out(south_ready_out),

        .east_data_out(east_data_out),
        .east_valid_out(east_valid_out),
        .east_ready_out(east_ready_out),

        .west_data_out(west_data_out),
        .west_valid_out(west_valid_out),
        .west_ready_out(west_ready_out)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Count actual successful EAST output transfers.
    always @(posedge clk) begin
        if (rst_n && east_valid_out && east_ready_out) begin
            packet = east_data_out;

            total_received = total_received + 1;

            if (packet[31:24] != 8'h21)
                $fatal(1, "Incorrect destination header: %h", packet);

            if (packet[7:4] == 4'hA) begin
                local_received = local_received + 1;
                consecutive_local = consecutive_local + 1;
                consecutive_north = 0;

                if (consecutive_local > max_consecutive_local)
                    max_consecutive_local = consecutive_local;

                if (local_received <= 3)
                    $display("EAST received LOCAL packet: %h", packet);
            end
            else if (packet[7:4] == 4'hB) begin
                north_received = north_received + 1;
                consecutive_north = consecutive_north + 1;
                consecutive_local = 0;

                if (consecutive_north > max_consecutive_north)
                    max_consecutive_north = consecutive_north;

                if (north_received <= 3)
                    $display("EAST received NORTH packet: %h", packet);
            end
            else begin
                $fatal(1, "Unknown packet source marker: %h", packet);
            end

            if (total_received > TOTAL_PACKETS)
                $fatal(1, "Received too many packets");
        end
    end

    // LOCAL continuously supplies packets to EAST.
    initial begin
        wait (rst_n == 1'b1);
        @(negedge clk);

        for (local_sent = 0;
             local_sent < PACKETS_PER_INPUT;
             local_sent = local_sent + 1) begin

            local_data_in = 32'h2100_00A0 | local_sent;
            local_valid_in = 1'b1;

            do begin
                @(posedge clk);
            end while (local_ready_in !== 1'b1);

            @(negedge clk);
            local_valid_in = 1'b0;
        end
    end

    // NORTH continuously supplies packets to EAST.
    initial begin
        wait (rst_n == 1'b1);
        @(negedge clk);

        for (north_sent = 0;
             north_sent < PACKETS_PER_INPUT;
             north_sent = north_sent + 1) begin

            north_data_in = 32'h2100_00B0 | north_sent;
            north_valid_in = 1'b1;

            do begin
                @(posedge clk);
            end while (north_ready_in !== 1'b1);

            @(negedge clk);
            north_valid_in = 1'b0;
        end
    end

    initial begin
        rst_n = 1'b0;
        router_x = 4'd1;
        router_y = 4'd1;

        local_data_in = '0;
        local_valid_in = 1'b0;

        north_data_in = '0;
        north_valid_in = 1'b0;

        south_data_in = '0;
        south_valid_in = 1'b0;

        east_data_in = '0;
        east_valid_in = 1'b0;

        west_data_in = '0;
        west_valid_in = 1'b0;

        local_ready_out = 1'b1;
        north_ready_out = 1'b1;
        south_ready_out = 1'b1;
        east_ready_out = 1'b1;
        west_ready_out = 1'b1;

        local_sent = 0;
        north_sent = 0;

        local_received = 0;
        north_received = 0;
        total_received = 0;

        consecutive_local = 0;
        consecutive_north = 0;
        max_consecutive_local = 0;
        max_consecutive_north = 0;

        packet = '0;

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        $display("TEST: Sustained LOCAL and NORTH contention for EAST");

        // Allow both streams to finish and all packets to drain.
        wait (total_received == TOTAL_PACKETS);

        @(negedge clk);

        $display("");
        $display("Total EAST transfers : %0d", total_received);
        $display("LOCAL packets served : %0d", local_received);
        $display("NORTH packets served : %0d", north_received);
        $display("Max consecutive LOCAL grants : %0d",
                 max_consecutive_local);
        $display("Max consecutive NORTH grants : %0d",
                 max_consecutive_north);

        if (local_received != PACKETS_PER_INPUT)
            $fatal(1, "LOCAL fairness failure: received %0d",
                   local_received);

        if (north_received != PACKETS_PER_INPUT)
            $fatal(1, "NORTH fairness failure: received %0d",
                   north_received);

        if (total_received != TOTAL_PACKETS)
            $fatal(1, "Transfer count mismatch");

        $display("");
        $display("PASS: Both inputs received service");
        $display("PASS: All packets reached EAST");
        $display("ALL FAIRNESS TESTS PASSED");

        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "TIMEOUT: fairness test did not complete");
    end

endmodule
