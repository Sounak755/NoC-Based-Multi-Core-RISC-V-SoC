
`timescale 1ns/1ps

module rv32i_noc_multicore_subsystem_tb;

    logic clk = 0;
    logic rst_n = 0;

    logic [3:0][31:0] instruction_address;
    logic [3:0][31:0] instruction_data;

    logic [3:0]       retire_valid;
    logic [3:0][31:0] retire_pc;
    logic [3:0][31:0] retire_instruction;
    logic [3:0]       retire_rd_we;
    logic [3:0][4:0]  retire_rd;
    logic [3:0][31:0] retire_rd_data;

    logic [3:0] memory_request_active;
    logic [3:0] memory_response_active;
    logic [3:0] fabric_protocol_errors;

    integer failures = 0;
    integer cycles = 0;
    integer retire_count [0:3];
    integer c;
    integer p;

    logic [31:0] instruction_rom [0:3][0:15];

    integer request_events [0:3];
    integer service_response_events [0:3];
    integer source_response_events [0:3];

    integer txn_accept_events [0:3];
    integer inject_events [0:3];
    integer ejection_events [0:3];

    always #5 clk = ~clk;

    rv32i_noc_multicore_subsystem #(
        .FIFO_DEPTH(8),
        .MEM_BYTES(1024)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .instruction_address(instruction_address),
        .instruction_data(instruction_data),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_instruction(retire_instruction),
        .retire_rd_we(retire_rd_we),
        .retire_rd(retire_rd),
        .retire_rd_data(retire_rd_data),
        .memory_request_active(memory_request_active),
        .memory_response_active(memory_response_active),
        .fabric_protocol_errors(fabric_protocol_errors)
    );

    // Four independent instruction ROMs.
    always @(*) begin
        instruction_data[0] = 32'h00000013;
        instruction_data[1] = 32'h00000013;
        instruction_data[2] = 32'h00000013;
        instruction_data[3] = 32'h00000013;

        if (instruction_address[0] < 64)
            instruction_data[0] =
                instruction_rom[0][instruction_address[0][5:2]];

        if (instruction_address[1] < 64)
            instruction_data[1] =
                instruction_rom[1][instruction_address[1][5:2]];

        if (instruction_address[2] < 64)
            instruction_data[2] =
                instruction_rom[2][instruction_address[2][5:2]];

        if (instruction_address[3] < 64)
            instruction_data[3] =
                instruction_rom[3][instruction_address[3][5:2]];
    end

    // Count retired instructions independently for each core.
    always @(posedge clk) begin
        if (!rst_n) begin
            retire_count[0] <= 0;
            retire_count[1] <= 0;
            retire_count[2] <= 0;
            retire_count[3] <= 0;
        end else begin
            if (retire_valid[0])
                retire_count[0] <= retire_count[0] + 1;
            if (retire_valid[1])
                retire_count[1] <= retire_count[1] + 1;
            if (retire_valid[2])
                retire_count[2] <= retire_count[2] + 1;
            if (retire_valid[3])
                retire_count[3] <= retire_count[3] + 1;
        end
    end

    task automatic check(
        input logic condition,
        input string message
    );
        begin
            if (condition === 1'b1)
                $display("PASS: %s", message);
            else begin
                $display("FAIL: %s", message);
                failures = failures + 1;
            end
        end
    endtask

    // Diagnostics for each shared-fabric stage.
    // Fixed indices are intentional for Icarus Verilog compatibility.
    always @(posedge clk) begin
        if (!rst_n) begin
            for (integer k = 0; k < 4; k = k + 1) begin
                request_events[k]          <= 0;
                service_response_events[k] <= 0;
                source_response_events[k]  <= 0;
                txn_accept_events[k]       <= 0;
                inject_events[k]           <= 0;
                ejection_events[k]         <= 0;
            end
        end else begin

            // Transaction acceptance at the fabric interface.
            if (dut.u_shared_noc_fabric.txn_valid[0] &&
                dut.u_shared_noc_fabric.txn_ready[0]) begin
                if (txn_accept_events[0] < 8)
                    $display("[TXN ACCEPT] node=0 write=%b addr=%08h data=%08h",
                        dut.u_shared_noc_fabric.txn_write[0],
                        dut.u_shared_noc_fabric.txn_addr[0],
                        dut.u_shared_noc_fabric.txn_wdata[0]);
                txn_accept_events[0] <= txn_accept_events[0] + 1;
            end

            if (dut.u_shared_noc_fabric.txn_valid[1] &&
                dut.u_shared_noc_fabric.txn_ready[1]) begin
                if (txn_accept_events[1] < 8)
                    $display("[TXN ACCEPT] node=1 write=%b addr=%08h data=%08h",
                        dut.u_shared_noc_fabric.txn_write[1],
                        dut.u_shared_noc_fabric.txn_addr[1],
                        dut.u_shared_noc_fabric.txn_wdata[1]);
                txn_accept_events[1] <= txn_accept_events[1] + 1;
            end

            if (dut.u_shared_noc_fabric.txn_valid[2] &&
                dut.u_shared_noc_fabric.txn_ready[2]) begin
                if (txn_accept_events[2] < 8)
                    $display("[TXN ACCEPT] node=2 write=%b addr=%08h data=%08h",
                        dut.u_shared_noc_fabric.txn_write[2],
                        dut.u_shared_noc_fabric.txn_addr[2],
                        dut.u_shared_noc_fabric.txn_wdata[2]);
                txn_accept_events[2] <= txn_accept_events[2] + 1;
            end

            if (dut.u_shared_noc_fabric.txn_valid[3] &&
                dut.u_shared_noc_fabric.txn_ready[3]) begin
                if (txn_accept_events[3] < 8)
                    $display("[TXN ACCEPT] node=3 write=%b addr=%08h data=%08h",
                        dut.u_shared_noc_fabric.txn_write[3],
                        dut.u_shared_noc_fabric.txn_addr[3],
                        dut.u_shared_noc_fabric.txn_wdata[3]);
                txn_accept_events[3] <= txn_accept_events[3] + 1;
            end

            // Injection diagnostics.
            if (dut.u_shared_noc_fabric.inject_valid[0] &&
                dut.u_shared_noc_fabric.inject_ready[0]) begin
                if (inject_events[0] < 12)
                    $display("[INJECT] node=0 flit=%08h index=%0d",
                        dut.u_shared_noc_fabric.inject_data[0],
                        dut.u_shared_noc_fabric.inject_data[0][15:13]);
                inject_events[0] <= inject_events[0] + 1;
            end

            if (dut.u_shared_noc_fabric.inject_valid[1] &&
                dut.u_shared_noc_fabric.inject_ready[1]) begin
                if (inject_events[1] < 12)
                    $display("[INJECT] node=1 flit=%08h index=%0d",
                        dut.u_shared_noc_fabric.inject_data[1],
                        dut.u_shared_noc_fabric.inject_data[1][15:13]);
                inject_events[1] <= inject_events[1] + 1;
            end

            if (dut.u_shared_noc_fabric.inject_valid[2] &&
                dut.u_shared_noc_fabric.inject_ready[2]) begin
                if (inject_events[2] < 12)
                    $display("[INJECT] node=2 flit=%08h index=%0d",
                        dut.u_shared_noc_fabric.inject_data[2],
                        dut.u_shared_noc_fabric.inject_data[2][15:13]);
                inject_events[2] <= inject_events[2] + 1;
            end

            if (dut.u_shared_noc_fabric.inject_valid[3] &&
                dut.u_shared_noc_fabric.inject_ready[3]) begin
                if (inject_events[3] < 12)
                    $display("[INJECT] node=3 flit=%08h index=%0d",
                        dut.u_shared_noc_fabric.inject_data[3],
                        dut.u_shared_noc_fabric.inject_data[3][15:13]);
                inject_events[3] <= inject_events[3] + 1;
            end

            // Ejection diagnostics.
            if (dut.u_shared_noc_fabric.mesh_valid_out[0] &&
                dut.u_shared_noc_fabric.mesh_ready_out[0]) begin
                if (ejection_events[0] < 12)
                    $display("[EJECT] node=0 flit=%08h index=%0d",
                        dut.u_shared_noc_fabric.mesh_data_out[0],
                        dut.u_shared_noc_fabric.mesh_data_out[0][15:13]);
                ejection_events[0] <= ejection_events[0] + 1;
            end

            if (dut.u_shared_noc_fabric.mesh_valid_out[1] &&
                dut.u_shared_noc_fabric.mesh_ready_out[1]) begin
                if (ejection_events[1] < 12)
                    $display("[EJECT] node=1 flit=%08h index=%0d",
                        dut.u_shared_noc_fabric.mesh_data_out[1],
                        dut.u_shared_noc_fabric.mesh_data_out[1][15:13]);
                ejection_events[1] <= ejection_events[1] + 1;
            end

            if (dut.u_shared_noc_fabric.mesh_valid_out[2] &&
                dut.u_shared_noc_fabric.mesh_ready_out[2]) begin
                if (ejection_events[2] < 12)
                    $display("[EJECT] node=2 flit=%08h index=%0d",
                        dut.u_shared_noc_fabric.mesh_data_out[2],
                        dut.u_shared_noc_fabric.mesh_data_out[2][15:13]);
                ejection_events[2] <= ejection_events[2] + 1;
            end

            if (dut.u_shared_noc_fabric.mesh_valid_out[3] &&
                dut.u_shared_noc_fabric.mesh_ready_out[3]) begin
                if (ejection_events[3] < 12)
                    $display("[EJECT] node=3 flit=%08h index=%0d",
                        dut.u_shared_noc_fabric.mesh_data_out[3],
                        dut.u_shared_noc_fabric.mesh_data_out[3][15:13]);
                ejection_events[3] <= ejection_events[3] + 1;
            end

            // Decoded request accepted by memory service.
            for (integer k = 0; k < 4; k = k + 1) begin
                if (dut.u_shared_noc_fabric.req_dec_valid[k] &&
                    dut.u_shared_noc_fabric.req_dec_ready[k]) begin
                    if (request_events[k] < 8)
                        $display(
                            "[FABRIC REQUEST] node=%0d write=%b addr=%08h data=%08h src=(%0d,%0d) dst=(%0d,%0d)",
                            k,
                            dut.u_shared_noc_fabric.req_dec_write[k],
                            dut.u_shared_noc_fabric.req_dec_addr[k],
                            dut.u_shared_noc_fabric.req_dec_wdata[k],
                            dut.u_shared_noc_fabric.req_dec_src_x[k],
                            dut.u_shared_noc_fabric.req_dec_src_y[k],
                            dut.u_shared_noc_fabric.req_dec_dest_x[k],
                            dut.u_shared_noc_fabric.req_dec_dest_y[k]
                        );
                    request_events[k] <= request_events[k] + 1;
                end

                if (dut.u_shared_noc_fabric.svc_resp_valid[k] &&
                    dut.u_shared_noc_fabric.svc_resp_ready[k]) begin
                    if (service_response_events[k] < 8)
                        $display(
                            "[SERVICE RESPONSE] node=%0d src=(%0d,%0d) dst=(%0d,%0d) data=%08h error=%b",
                            k,
                            dut.u_shared_noc_fabric.svc_resp_src_x[k],
                            dut.u_shared_noc_fabric.svc_resp_src_y[k],
                            dut.u_shared_noc_fabric.svc_resp_dest_x[k],
                            dut.u_shared_noc_fabric.svc_resp_dest_y[k],
                            dut.u_shared_noc_fabric.svc_resp_rdata[k],
                            dut.u_shared_noc_fabric.svc_resp_error[k]
                        );
                    service_response_events[k] <=
                        service_response_events[k] + 1;
                end

                if (dut.u_shared_noc_fabric.source_resp_valid[k] &&
                    dut.u_shared_noc_fabric.source_resp_ready[k]) begin
                    if (source_response_events[k] < 8)
                        $display(
                            "[SOURCE RESPONSE] node=%0d data=%08h error=%b src=(%0d,%0d) dst=(%0d,%0d)",
                            k,
                            dut.u_shared_noc_fabric.source_resp_rdata[k],
                            dut.u_shared_noc_fabric.source_resp_error[k],
                            dut.u_shared_noc_fabric.source_resp_src_x[k],
                            dut.u_shared_noc_fabric.source_resp_src_y[k],
                            dut.u_shared_noc_fabric.source_resp_dest_x[k],
                            dut.u_shared_noc_fabric.source_resp_dest_y[k]
                        );
                    source_response_events[k] <=
                        source_response_events[k] + 1;
                end
            end
        end
    end

    initial begin
        for (c = 0; c < 4; c = c + 1) begin
            for (p = 0; p < 16; p = p + 1)
                instruction_rom[c][p] = 32'h00000013;
        end

        // Core 0: store and reload 17 from address 64.
        instruction_rom[0][0] = 32'h01100093;
        instruction_rom[0][1] = 32'h04000113;
        instruction_rom[0][2] = 32'h00112023;
        instruction_rom[0][3] = 32'h00012183;
        instruction_rom[0][4] = 32'h00118213;

        // Core 1: store and reload 34 from address 68.
        instruction_rom[1][0] = 32'h02200093;
        instruction_rom[1][1] = 32'h04400113;
        instruction_rom[1][2] = 32'h00112023;
        instruction_rom[1][3] = 32'h00012183;
        instruction_rom[1][4] = 32'h00118213;

        // Core 2: store and reload 51 from address 72.
        instruction_rom[2][0] = 32'h03300093;
        instruction_rom[2][1] = 32'h04800113;
        instruction_rom[2][2] = 32'h00112023;
        instruction_rom[2][3] = 32'h00012183;
        instruction_rom[2][4] = 32'h00118213;

        // Core 3: store and reload 68 from address 76.
        instruction_rom[3][0] = 32'h04400093;
        instruction_rom[3][1] = 32'h04C00113;
        instruction_rom[3][2] = 32'h00112023;
        instruction_rom[3][3] = 32'h00012183;
        instruction_rom[3][4] = 32'h00118213;

        $display("");
        $display("========================================");
        $display(" FOUR-CORE RV32I + SHARED NoC TEST");
        $display("========================================");

        repeat (4) @(negedge clk);
        rst_n = 1'b1;

        begin : RUN_TEST
            for (cycles = 0; cycles < 1500; cycles = cycles + 1) begin
                @(negedge clk);

                for (integer k = 0; k < 4; k = k + 1) begin
                    if (retire_valid[k] && retire_count[k] < 5) begin
                        $display(
                            "[RETIRE] core=%0d pc=%08h instr=%08h rd_we=%b rd=%0d data=%08h",
                            k,
                            retire_pc[k],
                            retire_instruction[k],
                            retire_rd_we[k],
                            retire_rd[k],
                            retire_rd_data[k]
                        );
                    end
                end

                if ((retire_count[0] >= 5) &&
                    (retire_count[1] >= 5) &&
                    (retire_count[2] >= 5) &&
                    (retire_count[3] >= 5))
                    disable RUN_TEST;
            end
        end

        repeat (30) @(negedge clk);

        $display("");
        $display("========== DIAGNOSTICS ==========");
        $display("Core request-active bits : %b", memory_request_active);
        $display("Core response-active bits: %b", memory_response_active);

        $display("Transactions accepted: %0d, %0d, %0d, %0d",
            txn_accept_events[0], txn_accept_events[1],
            txn_accept_events[2], txn_accept_events[3]);

        $display("Flits injected: %0d, %0d, %0d, %0d",
            inject_events[0], inject_events[1],
            inject_events[2], inject_events[3]);

        $display("Flits ejected: %0d, %0d, %0d, %0d",
            ejection_events[0], ejection_events[1],
            ejection_events[2], ejection_events[3]);

        $display("Request decoder handshakes: %0d, %0d, %0d, %0d",
            request_events[0], request_events[1],
            request_events[2], request_events[3]);

        $display("Service response handshakes: %0d, %0d, %0d, %0d",
            service_response_events[0], service_response_events[1],
            service_response_events[2], service_response_events[3]);

        $display("Source response handshakes: %0d, %0d, %0d, %0d",
            source_response_events[0], source_response_events[1],
            source_response_events[2], source_response_events[3]);

        $display("");
        $display("========== RESULTS ==========");

        check(retire_count[0] >= 5, "Core 0 retired at least five instructions");
        check(retire_count[1] >= 5, "Core 1 retired at least five instructions");
        check(retire_count[2] >= 5, "Core 2 retired at least five instructions");
        check(retire_count[3] >= 5, "Core 3 retired at least five instructions");

        check(
            dut.GEN_CORE[0].u_core.register_file.registers[3] === 32'h00000011,
            "Core 0 loaded its own stored value"
        );

        check(
            dut.GEN_CORE[1].u_core.register_file.registers[3] === 32'h00000022,
            "Core 1 loaded its own stored value"
        );

        check(
            dut.GEN_CORE[2].u_core.register_file.registers[3] === 32'h00000033,
            "Core 2 loaded its own stored value"
        );

        check(
            dut.GEN_CORE[3].u_core.register_file.registers[3] === 32'h00000044,
            "Core 3 loaded its own stored value"
        );

        check(
            fabric_protocol_errors === 4'b0000,
            "No NoC protocol errors"
        );

        $display("Retire counts: %0d, %0d, %0d, %0d",
            retire_count[0], retire_count[1],
            retire_count[2], retire_count[3]);

        $display("Protocol errors: %b", fabric_protocol_errors);

        if (failures == 0)
            $display("ALL FOUR-CORE CHECKS PASSED");
        else
            $fatal(1, "TEST FAILED: %0d checks failed", failures);

        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Simulation timeout");
    end

endmodule
