
`timescale 1ns/1ps

module rv32i_noc_memory_adapter_tb;

    logic clk = 0;
    logic rst_n = 0;

    logic cpu_req_valid;
    logic cpu_req_ready;
    logic cpu_req_write;
    logic [31:0] cpu_req_addr;
    logic [31:0] cpu_req_wdata;
    logic [2:0] cpu_req_funct3;

    logic cpu_resp_valid;
    logic cpu_resp_ready;
    logic [31:0] cpu_resp_rdata;

    logic noc_req_valid;
    logic noc_req_ready;
    logic noc_req_write;
    logic [31:0] noc_req_addr;
    logic [31:0] noc_req_wdata;
    logic [2:0] noc_req_funct3;

    logic noc_resp_valid;
    logic noc_resp_ready;
    logic [31:0] noc_resp_rdata;

    integer checks = 0;

    always #5 clk = ~clk;

    rv32i_noc_memory_adapter dut (
        .clk(clk),
        .rst_n(rst_n),

        .cpu_req_valid(cpu_req_valid),
        .cpu_req_ready(cpu_req_ready),
        .cpu_req_write(cpu_req_write),
        .cpu_req_addr(cpu_req_addr),
        .cpu_req_wdata(cpu_req_wdata),
        .cpu_req_funct3(cpu_req_funct3),

        .cpu_resp_valid(cpu_resp_valid),
        .cpu_resp_ready(cpu_resp_ready),
        .cpu_resp_rdata(cpu_resp_rdata),

        .noc_req_valid(noc_req_valid),
        .noc_req_ready(noc_req_ready),
        .noc_req_write(noc_req_write),
        .noc_req_addr(noc_req_addr),
        .noc_req_wdata(noc_req_wdata),
        .noc_req_funct3(noc_req_funct3),

        .noc_resp_valid(noc_resp_valid),
        .noc_resp_ready(noc_resp_ready),
        .noc_resp_rdata(noc_resp_rdata)
    );

    task automatic check(input logic condition, input string message);
        begin
            if (condition !== 1'b1) begin
                $display("FAIL: %s", message);
                $fatal(1);
            end
            checks = checks + 1;
            $display("PASS: %s", message);
        end
    endtask

    initial begin
        cpu_req_valid = 0;
        cpu_req_write = 0;
        cpu_req_addr = 0;
        cpu_req_wdata = 0;
        cpu_req_funct3 = 3'b010;
        cpu_resp_ready = 0;

        noc_req_ready = 0;
        noc_resp_valid = 0;
        noc_resp_rdata = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // Issue a store request.
        cpu_req_valid = 1;
        cpu_req_write = 1;
        cpu_req_addr = 32'h00000120;
        cpu_req_wdata = 32'hDEADBEEF;
        cpu_req_funct3 = 3'b010;

        check(cpu_req_ready, "Adapter accepts request while idle");

        @(posedge clk);
        @(negedge clk);
        cpu_req_valid = 0;

        // Downstream is not ready: request must remain asserted and stable.
        check(noc_req_valid, "Downstream request becomes valid");
        check(noc_req_write, "Write operation is preserved");
        check(noc_req_addr == 32'h00000120, "Address is preserved");
        check(noc_req_wdata == 32'hDEADBEEF, "Write data is preserved");
        check(noc_req_funct3 == 3'b010, "Access size is preserved");
        check(!cpu_req_ready, "Adapter blocks a second request");

        repeat (2) begin
            @(negedge clk);
            check(noc_req_valid, "Request remains valid during backpressure");
            check(noc_req_addr == 32'h00000120, "Request address remains stable");
        end

        // Downstream accepts the request.
        noc_req_ready = 1;
        @(posedge clk);
        @(negedge clk);
        noc_req_ready = 0;

        check(!noc_req_valid, "Request deasserts after acceptance");
        check(noc_resp_ready, "Adapter waits for downstream response");

        // Deliver the response.
        noc_resp_rdata = 32'h12345678;
        noc_resp_valid = 1;
        @(posedge clk);
        @(negedge clk);
        noc_resp_valid = 0;

        check(cpu_resp_valid, "CPU response becomes valid");
        check(cpu_resp_rdata == 32'h12345678, "Read response data is preserved");
        check(!cpu_req_ready, "Adapter remains busy until CPU accepts response");

        // Hold the CPU response under backpressure.
        repeat (2) begin
            @(negedge clk);
            check(cpu_resp_valid, "CPU response remains valid during backpressure");
            check(cpu_resp_rdata == 32'h12345678, "Response data remains stable");
        end

        // CPU accepts the response.
        cpu_resp_ready = 1;
        @(posedge clk);
        @(negedge clk);
        cpu_resp_ready = 0;

        check(!cpu_resp_valid, "Response clears after CPU acceptance");
        check(cpu_req_ready, "Adapter returns to idle");

        $display("");
        $display("==========================================");
        $display("ALL ADAPTER TESTS PASSED (%0d checks)", checks);
        $display("==========================================");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "TIMEOUT: adapter test did not finish");
    end

endmodule
