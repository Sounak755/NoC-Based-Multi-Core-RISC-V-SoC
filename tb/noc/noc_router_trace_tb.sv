
`timescale 1ns/1ps

module noc_router_trace_tb;
    reg clk = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    reg [31:0] data_in_00 = 0;
    reg valid_in_00 = 0;
    wire ready_in_00;

    wire [31:0] data_out_11;
    wire valid_out_11;
    reg ready_out_11 = 1;

    noc_mesh_2x2 dut (
        .clk(clk), .rst_n(rst_n),

        .local_data_in_00(data_in_00),
        .local_valid_in_00(valid_in_00),
        .local_ready_in_00(ready_in_00),
        .local_data_out_00(),
        .local_valid_out_00(),
        .local_ready_out_00(1'b1),

        .local_data_in_10(32'b0),
        .local_valid_in_10(1'b0),
        .local_ready_in_10(),
        .local_data_out_10(),
        .local_valid_out_10(),
        .local_ready_out_10(1'b1),

        .local_data_in_01(32'b0),
        .local_valid_in_01(1'b0),
        .local_ready_in_01(),
        .local_data_out_01(),
        .local_valid_out_01(),
        .local_ready_out_01(1'b1),

        .local_data_in_11(32'b0),
        .local_valid_in_11(1'b0),
        .local_ready_in_11(),
        .local_data_out_11(data_out_11),
        .local_valid_out_11(valid_out_11),
        .local_ready_out_11(ready_out_11)
    );

    integer sent = 0;
    integer received = 0;
    integer i;
    reg [31:0] flit;

    always @(posedge clk) begin
        if (rst_n && valid_out_11 && ready_out_11) begin
            received = received + 1;
            $display("EJECT %0d: %h at time %0t",
                     received, data_out_11, $time);
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;

        for (i = 0; i < 6; i = i + 1) begin
            flit = 32'h11000000 | (i << 13) | i;

            @(negedge clk);
            data_in_00 = flit;
            valid_in_00 = 1;

            do @(posedge clk); while (ready_in_00 !== 1'b1);
            sent = sent + 1;

            @(negedge clk);
            valid_in_00 = 0;
        end

        repeat (12) @(negedge clk);

        $display("Flits accepted: %0d; flits ejected: %0d",
                 sent, received);

        if (sent == 6 && received == 6)
            $display("PASS: ALL SIX FLITS CROSSED THE MESH");
        else
            $display("FAIL: MULTI-FLIT MESH TRANSFER");

        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Mesh trace timed out");
    end
endmodule
