
`timescale 1ns/1ps

module noc_memory_contention_tb;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic [3:0]       txn_valid;
    logic [3:0]       txn_ready;
    logic [3:0][3:0]  txn_dest_x;
    logic [3:0][3:0]  txn_dest_y;
    logic [3:0]       txn_write;
    logic [3:0][2:0] txn_funct3;
    logic [3:0][31:0] txn_addr;
    logic [3:0][31:0] txn_wdata;

    logic [3:0]       node_resp_valid;
    logic [3:0]       node_resp_ready;
    logic [3:0][3:0]  node_resp_src_x;
    logic [3:0][3:0]  node_resp_src_y;
    logic [3:0][3:0]  node_resp_dest_x;
    logic [3:0][3:0]  node_resp_dest_y;
    logic [3:0][31:0] node_resp_rdata;
    logic [3:0]       node_resp_error;
    logic [3:0]       node_protocol_error;

    logic [3:0]       source_resp_valid;
    logic [3:0]       source_resp_ready;
    logic [3:0][3:0]  source_resp_src_x;
    logic [3:0][3:0]  source_resp_src_y;
    logic [3:0][3:0]  source_resp_dest_x;
    logic [3:0][3:0]  source_resp_dest_y;
    logic [3:0][31:0] source_resp_rdata;
    logic [3:0]       source_resp_error;
    logic [3:0]       response_protocol_error;

    integer response_count;
    integer accepted_count;
    integer decoder_count [0:3];
    integer service_count [0:3];
    integer flit_count [0:3];
    integer errors;
    integer i;
    integer baseline;
    integer trace_cycles;
    integer inject_trace_count;
    integer r11_trace_count;

    logic [3:0] accepted_mask;
    logic [31:0] readback [0:3];
    logic [3:0] readback_seen;

    noc_memory_fabric_2x2 #(
        .FIFO_DEPTH(8),
        .MEM_BYTES(1024)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .txn_valid(txn_valid),
        .txn_ready(txn_ready),
        .txn_dest_x(txn_dest_x),
        .txn_dest_y(txn_dest_y),
        .txn_write(txn_write),
        .txn_funct3(txn_funct3),
        .txn_addr(txn_addr),
        .txn_wdata(txn_wdata),

        .node_resp_valid(node_resp_valid),
        .node_resp_ready(node_resp_ready),
        .node_resp_src_x(node_resp_src_x),
        .node_resp_src_y(node_resp_src_y),
        .node_resp_dest_x(node_resp_dest_x),
        .node_resp_dest_y(node_resp_dest_y),
        .node_resp_rdata(node_resp_rdata),
        .node_resp_error(node_resp_error),
        .node_protocol_error(node_protocol_error),

        .source_resp_valid(source_resp_valid),
        .source_resp_ready(source_resp_ready),
        .source_resp_src_x(source_resp_src_x),
        .source_resp_src_y(source_resp_src_y),
        .source_resp_dest_x(source_resp_dest_x),
        .source_resp_dest_y(source_resp_dest_y),
        .source_resp_rdata(source_resp_rdata),
        .source_resp_error(source_resp_error),
        .response_protocol_error(response_protocol_error)
    );

    always #5 clk = ~clk;

    // ============================================================
    // Count handshakes and record responses.
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            response_count = 0;
            accepted_count = 0;
            accepted_mask = 4'b0000;
            readback_seen = 4'b0000;

            for (integer k = 0; k < 4; k = k + 1) begin
                decoder_count[k] = 0;
                service_count[k] = 0;
                flit_count[k] = 0;
                readback[k] = 32'b0;
            end
        end else begin
            for (integer k = 0; k < 4; k = k + 1) begin
                if (txn_valid[k] && txn_ready[k]) begin
                    accepted_mask[k] = 1'b1;
                    accepted_count = accepted_count + 1;
                end

                if (dut.req_flit_valid[k] &&
                    dut.req_flit_ready[k])
                    flit_count[k] = flit_count[k] + 1;

                if (dut.req_dec_valid[k] &&
                    dut.req_dec_ready[k])
                    decoder_count[k] = decoder_count[k] + 1;

                if (dut.svc_resp_valid[k] &&
                    dut.svc_resp_ready[k])
                    service_count[k] = service_count[k] + 1;

                if (source_resp_valid[k] &&
                    source_resp_ready[k]) begin
                    response_count = response_count + 1;
                    readback[k] = source_resp_rdata[k];
                    readback_seen[k] = 1'b1;

                    $display(
                        "[SOURCE RESPONSE] t=%0t source=%0d data=%08h error=%b",
                        $time, k, source_resp_rdata[k],
                        source_resp_error[k]
                    );
                end
            end
        end
    end

    // ============================================================
    // Trace request injection into the mesh.
    // ============================================================
    always @(negedge clk) begin
        if (rst_n && (|dut.req_flit_valid) &&
            inject_trace_count < 16) begin

            inject_trace_count = inject_trace_count + 1;

            $display("");
            $display("[INJECTION] t=%0t trace=%0d",
                     $time, inject_trace_count);

            $display("  req_valid=%b req_ready=%b",
                     dut.req_flit_valid, dut.req_flit_ready);

            $display("  req_data=%h", dut.req_flit_data);

            $display("  inject_valid=%b inject_ready=%b",
                     dut.inject_valid, dut.inject_ready);

            $display("  inject_data=%h", dut.inject_data);

            $display("  mesh_valid_in=%b mesh_ready_in=%b",
                     dut.mesh_valid_in, dut.mesh_ready_in);

            $display("  mesh_data_in=%h", dut.mesh_data_in);
        end
    end

    // ============================================================
    // ============================================================
    // Diagnostic: trace the two links entering R11.
    // ============================================================
    always @(negedge clk) begin
        if (rst_n &&
            (dut.u_mesh.link_10_to_11_valid ||
             dut.u_mesh.link_01_to_11_valid)) begin

            $display(
                "LINK TRACE t=%0t | R10->R11 data=%08h valid=%b ready=%b | R01->R11 data=%08h valid=%b ready=%b",
                $time,
                dut.u_mesh.link_10_to_11_data,
                dut.u_mesh.link_10_to_11_valid,
                dut.u_mesh.link_11_south_input_ready,
                dut.u_mesh.link_01_to_11_data,
                dut.u_mesh.link_01_to_11_valid,
                dut.u_mesh.link_11_west_input_ready
            );
        end
    end
    // Temporary five-port diagnostic
    always @(negedge clk) begin
        if (rst_n && $time >= 100000 && $time <= 160000) begin
            $display(
                "R01 ports: LOCAL=%08h/%08h NORTH=%08h/%08h SOUTH=%08h/%08h EAST=%08h/%08h WEST=%08h/%08h",
                dut.u_mesh.R01.output_data[0], dut.u_mesh.R01.local_data_out,
                dut.u_mesh.R01.output_data[1], dut.u_mesh.R01.north_data_out,
                dut.u_mesh.R01.output_data[2], dut.u_mesh.R01.south_data_out,
                dut.u_mesh.R01.output_data[3], dut.u_mesh.R01.east_data_out,
                dut.u_mesh.R01.output_data[4], dut.u_mesh.R01.west_data_out
            );
            $display(
                "R10 ports: LOCAL=%08h/%08h NORTH=%08h/%08h SOUTH=%08h/%08h EAST=%08h/%08h WEST=%08h/%08h",
                dut.u_mesh.R10.output_data[0], dut.u_mesh.R10.local_data_out,
                dut.u_mesh.R10.output_data[1], dut.u_mesh.R10.north_data_out,
                dut.u_mesh.R10.output_data[2], dut.u_mesh.R10.south_data_out,
                dut.u_mesh.R10.output_data[3], dut.u_mesh.R10.east_data_out,
                dut.u_mesh.R10.output_data[4], dut.u_mesh.R10.west_data_out
            );
        end
    end
    always @(negedge clk) begin
        if (rst_n && $time >= 100000 && $time <= 200000) begin
            $display(
                "ROUTE t=%0t | R10 local valid=%b data=%08h req_valid=%b req_out=%0d | R10 south grant=%b out_valid=%b out_data=%08h",
                $time,
                dut.u_mesh.R10.buffered_valid[0],
                dut.u_mesh.R10.buffered_data[0],
                dut.u_mesh.R10.request_valid[0],
                dut.u_mesh.R10.requested_output[0],
                dut.u_mesh.R10.grant_by_output[2],
                dut.u_mesh.R10.output_valid[2],
                dut.u_mesh.R10.output_data[2]
            );
            $display(
                "ROUTE R01 local valid=%b data=%08h req_valid=%b req_out=%0d | R01 east grant=%b out_valid=%b out_data=%08h",
                dut.u_mesh.R01.buffered_valid[0],
                dut.u_mesh.R01.buffered_data[0],
                dut.u_mesh.R01.request_valid[0],
                dut.u_mesh.R01.requested_output[0],
                dut.u_mesh.R01.grant_by_output[3],
                dut.u_mesh.R01.output_valid[3],
                dut.u_mesh.R01.output_data[3]
            );
        end
    end
    // R11 diagnostic: inspect every input buffer, route request,
    // arbitration grant, crossbar output and mesh ejection.
    //
    // This is diagnostic-only. No RTL signals are driven here.
    // ============================================================
    always @(negedge clk) begin
        if (rst_n &&
            r11_trace_count < 64 &&
            (
                dut.u_mesh.R11.buffered_valid[0] ||
                dut.u_mesh.R11.buffered_valid[1] ||
                dut.u_mesh.R11.buffered_valid[2] ||
                dut.u_mesh.R11.buffered_valid[3] ||
                dut.u_mesh.R11.buffered_valid[4]
            )) begin

            r11_trace_count = r11_trace_count + 1;

            $display("");
            $display("========== R11 INPUT TRACE t=%0t count=%0d ==========",
                     $time, r11_trace_count);

            $display("buffered_valid = %b",
                     dut.u_mesh.R11.buffered_valid);

            $display("input_pop_ready = %b",
                     dut.u_mesh.R11.input_pop_ready);

            $display("buffered_data[0] LOCAL = %08h",
                     dut.u_mesh.R11.buffered_data[0]);

            $display("buffered_data[1] NORTH = %08h",
                     dut.u_mesh.R11.buffered_data[1]);

            $display("buffered_data[2] SOUTH = %08h",
                     dut.u_mesh.R11.buffered_data[2]);

            $display("buffered_data[3] EAST  = %08h",
                     dut.u_mesh.R11.buffered_data[3]);

            $display("buffered_data[4] WEST  = %08h",
                     dut.u_mesh.R11.buffered_data[4]);

            $display("request_valid = %b",
                     dut.u_mesh.R11.request_valid);

            $display("requested_output[0..4] = %0d %0d %0d %0d %0d",
                     dut.u_mesh.R11.requested_output[0],
                     dut.u_mesh.R11.requested_output[1],
                     dut.u_mesh.R11.requested_output[2],
                     dut.u_mesh.R11.requested_output[3],
                     dut.u_mesh.R11.requested_output[4]);

            $display("grant LOCAL = %b",
                     dut.u_mesh.R11.grant_by_output[0]);

            $display("grant NORTH = %b",
                     dut.u_mesh.R11.grant_by_output[1]);

            $display("grant SOUTH = %b",
                     dut.u_mesh.R11.grant_by_output[2]);

            $display("grant EAST = %b",
                     dut.u_mesh.R11.grant_by_output[3]);

            $display("grant WEST = %b",
                     dut.u_mesh.R11.grant_by_output[4]);

            $display("output_data LOCAL=%08h valid=%b ready=%b",
                     dut.u_mesh.R11.output_data[0],
                     dut.u_mesh.R11.output_valid[0],
                     dut.u_mesh.R11.output_ready[0]);

            $display("output_data NORTH=%08h valid=%b ready=%b",
                     dut.u_mesh.R11.output_data[1],
                     dut.u_mesh.R11.output_valid[1],
                     dut.u_mesh.R11.output_ready[1]);

            $display("output_data SOUTH=%08h valid=%b ready=%b",
                     dut.u_mesh.R11.output_data[2],
                     dut.u_mesh.R11.output_valid[2],
                     dut.u_mesh.R11.output_ready[2]);

            $display("output_data EAST=%08h valid=%b ready=%b",
                     dut.u_mesh.R11.output_data[3],
                     dut.u_mesh.R11.output_valid[3],
                     dut.u_mesh.R11.output_ready[3]);

            $display("output_data WEST=%08h valid=%b ready=%b",
                     dut.u_mesh.R11.output_data[4],
                     dut.u_mesh.R11.output_valid[4],
                     dut.u_mesh.R11.output_ready[4]);

            $display("mesh_eject_node3=%08h valid=%b ready=%b",
                     dut.mesh_data_out[3],
                     dut.mesh_valid_out[3],
                     dut.mesh_ready_out[3]);

            $display("eject_response=%b req_flit_valid=%b req_flit_ready=%b",
                     dut.eject_is_response[3],
                     dut.req_decoder_flit_valid[3],
                     dut.req_decoder_flit_ready[3]);

            $display("======================================================");
        end
    end

    // ============================================================
    // Mesh ejection trace.
    // Explicit constant indices are used for Icarus compatibility.
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            trace_cycles <= 0;
        end else if (trace_cycles < 500) begin
            trace_cycles <= trace_cycles + 1;

            if (|dut.mesh_valid_out) begin
                $display("[MESH EJECT] t=%0t valid=%b ready=%b",
                         $time, dut.mesh_valid_out, dut.mesh_ready_out);

                if (dut.mesh_valid_out[0])
                    $display(
                        "  node=0 flit=%08h seq=%0d response=%b req_valid=%b req_ready=%b",
                        dut.mesh_data_out[0],
                        dut.mesh_data_out[0][15:13],
                        dut.eject_is_response[0],
                        dut.req_decoder_flit_valid[0],
                        dut.req_decoder_flit_ready[0]
                    );

                if (dut.mesh_valid_out[1])
                    $display(
                        "  node=1 flit=%08h seq=%0d response=%b req_valid=%b req_ready=%b",
                        dut.mesh_data_out[1],
                        dut.mesh_data_out[1][15:13],
                        dut.eject_is_response[1],
                        dut.req_decoder_flit_valid[1],
                        dut.req_decoder_flit_ready[1]
                    );

                if (dut.mesh_valid_out[2])
                    $display(
                        "  node=2 flit=%08h seq=%0d response=%b req_valid=%b req_ready=%b",
                        dut.mesh_data_out[2],
                        dut.mesh_data_out[2][15:13],
                        dut.eject_is_response[2],
                        dut.req_decoder_flit_valid[2],
                        dut.req_decoder_flit_ready[2]
                    );

                if (dut.mesh_valid_out[3])
                    $display(
                        "  node=3 flit=%08h seq=%0d response=%b req_valid=%b req_ready=%b",
                        dut.mesh_data_out[3],
                        dut.mesh_data_out[3][15:13],
                        dut.eject_is_response[3],
                        dut.req_decoder_flit_valid[3],
                        dut.req_decoder_flit_ready[3]
                    );
            end
        end
    end

    // ============================================================
    // Launch four concurrent memory transactions.
    // All requests target memory node (1,1).
    // ============================================================
    task automatic launch_batch(input logic is_write);
        integer local_timeout;
        begin
            @(negedge clk);
            accepted_mask = 4'b0000;

            for (integer k = 0; k < 4; k = k + 1) begin
                txn_valid[k]  = 1'b1;
                txn_dest_x[k] = 4'd1;
                txn_dest_y[k] = 4'd1;
                txn_write[k]  = is_write;
                txn_funct3[k] = 3'b010;
                txn_addr[k]   = 32'd32 + (k * 4);
                txn_wdata[k]  = 32'hC0DE0000 + k;
            end

            local_timeout = 0;

            while ((accepted_mask != 4'b1111) &&
                   (local_timeout < 100)) begin
                @(negedge clk);
                local_timeout = local_timeout + 1;
            end

            if (accepted_mask != 4'b1111) begin
                $display(
                    "FAIL: batch acceptance timeout accepted=%b ready=%b",
                    accepted_mask, txn_ready
                );
                $fatal(1, "Batch launch failed");
            end

            txn_valid = 4'b0000;

            $display("[BATCH ACCEPTED] t=%0t operation=%s",
                     $time, is_write ? "WRITE" : "READ");
        end
    endtask

    // ============================================================
    // Wait for all four responses, with diagnostic timeout.
    // ============================================================
    task automatic wait_for_responses(
        input integer target_count,
        input string phase_name
    );
        integer local_timeout;
        begin
            local_timeout = 0;

            while ((response_count < target_count) &&
                   (local_timeout < 500)) begin
                @(negedge clk);
                local_timeout = local_timeout + 1;
            end

            if (response_count < target_count) begin
                $display("");
                $display("========== CONTENTION FAILURE TRACE ==========");
                $display("Phase: %s", phase_name);
                $display("Wait cycles: %0d", local_timeout);
                $display("Accepted transactions: %0d", accepted_count);

                $display("Request flits accepted: %0d %0d %0d %0d",
                         flit_count[0], flit_count[1],
                         flit_count[2], flit_count[3]);

                $display("Request decoder handshakes: %0d %0d %0d %0d",
                         decoder_count[0], decoder_count[1],
                         decoder_count[2], decoder_count[3]);

                $display("Service response handshakes: %0d %0d %0d %0d",
                         service_count[0], service_count[1],
                         service_count[2], service_count[3]);

                $display("Source responses: %0d", response_count);

                $display("Mesh valid=%b ready=%b",
                         dut.mesh_valid_out, dut.mesh_ready_out);

                $display("Decoder valid=%b ready=%b",
                         dut.req_dec_valid, dut.req_dec_ready);

                $display("Ejection request valid=%b ready=%b",
                         dut.req_decoder_flit_valid,
                         dut.req_decoder_flit_ready);

                $display("Service response valid=%b ready=%b",
                         dut.svc_resp_valid, dut.svc_resp_ready);

                $display("Source response valid=%b",
                         source_resp_valid);

                $display("Node protocol errors=%b",
                         node_protocol_error);

                $display("Response protocol errors=%b",
                         response_protocol_error);

                $display("==============================================");

                $fatal(1, "Timed out waiting for %s responses", phase_name);
            end
        end
    endtask

    // ============================================================
    // Main test.
    // ============================================================
    initial begin
        txn_valid = 4'b0000;
        txn_dest_x = '0;
        txn_dest_y = '0;
        txn_write = '0;
        txn_funct3 = '0;
        txn_addr = '0;
        txn_wdata = '0;

        node_resp_ready = 4'b1111;
        source_resp_ready = 4'b1111;

        errors = 0;
        trace_cycles = 0;
        inject_trace_count = 0;
        r11_trace_count = 0;
        baseline = 0;

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (3) @(negedge clk);

        // Four simultaneous writes.
        baseline = response_count;
        launch_batch(1'b1);
        wait_for_responses(baseline + 4, "WRITE");

        $display("");
        $display("All write responses received. Launching reads.");

        // Four simultaneous reads.
        baseline = response_count;
        launch_batch(1'b0);
        wait_for_responses(baseline + 4, "READ");

        for (i = 0; i < 4; i = i + 1) begin
            if (!readback_seen[i]) begin
                $display(
                    "FAIL: source %0d did not return read data", i
                );
                errors = errors + 1;
            end else if (readback[i] !== (32'hC0DE0000 + i)) begin
                $display(
                    "FAIL: source %0d expected %08h got %08h",
                    i, (32'hC0DE0000 + i), readback[i]
                );
                errors = errors + 1;
            end else begin
                $display(
                    "PASS: source %0d read back %08h",
                    i, readback[i]
                );
            end
        end

        if (node_protocol_error !== 4'b0000) begin
            $display(
                "FAIL: node protocol errors=%b", node_protocol_error
            );
            errors = errors + 1;
        end

        if (response_protocol_error !== 4'b0000) begin
            $display(
                "FAIL: response protocol errors=%b",
                response_protocol_error
            );
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("");
            $display("ALL FOUR-SOURCE CONTENTION CHECKS PASSED");
            $finish;
        end else begin
            $fatal(1, "Contention test failed with %0d errors", errors);
        end
    end

    initial begin
        #200000;
        $fatal(1, "Global simulation timeout");
    end
always @(negedge clk) begin
    if (rst_n && $time < 250000) begin
        $display("UPSTREAM t=%0t | R10 south data=%08h valid=%b | R01 east data=%08h valid=%b",
            $time,
            dut.u_mesh.R10.output_data[2],
            dut.u_mesh.R10.output_valid[2],
            dut.u_mesh.R01.output_data[3],
            dut.u_mesh.R01.output_valid[3]
        );

        $display("R10 buffers: valid=%b L=%08h N=%08h S=%08h E=%08h W=%08h grants_south=%b",
            dut.u_mesh.R10.buffered_valid,
            dut.u_mesh.R10.buffered_data[0],
            dut.u_mesh.R10.buffered_data[1],
            dut.u_mesh.R10.buffered_data[2],
            dut.u_mesh.R10.buffered_data[3],
            dut.u_mesh.R10.buffered_data[4],
            dut.u_mesh.R10.grant_by_output[2]
        );

        $display("R01 buffers: valid=%b L=%08h N=%08h S=%08h E=%08h W=%08h grants_east=%b",
            dut.u_mesh.R01.buffered_valid,
            dut.u_mesh.R01.buffered_data[0],
            dut.u_mesh.R01.buffered_data[1],
            dut.u_mesh.R01.buffered_data[2],
            dut.u_mesh.R01.buffered_data[3],
            dut.u_mesh.R01.buffered_data[4],
            dut.u_mesh.R01.grant_by_output[3]
        );
    end
end
always @(posedge clk) begin
    if (rst_n) begin
        if (dut.mesh_valid_in[1] || dut.mesh_valid_in[2] ||
            dut.mesh_valid_in[3]) begin
            $display(
                "[INJECT] t=%0t valid=%b data0=%h data1=%h data2=%h data3=%h",
                $time,
                dut.mesh_valid_in,
                dut.mesh_data_in[0],
                dut.mesh_data_in[1],
                dut.mesh_data_in[2],
                dut.mesh_data_in[3]
            );
        end

        if (dut.mesh_valid_out[3]) begin
            $display(
                "[R11 EJECT] t=%0t valid=%b data=%h",
                $time,
                dut.mesh_valid_out[3],
                dut.mesh_data_out[3]
            );
        end
    end
end
always @(negedge clk) begin
    if (rst_n &&
        (dut.u_mesh.R11.buffered_valid[2] ||
         dut.u_mesh.R11.buffered_valid[4])) begin

        $display(
            "[R11 FIFO] t=%0t valid=%b | SOUTH: in=%h v=%b wr=%b head=%h empty=%b rd=%b | WEST: in=%h v=%b wr=%b head=%h empty=%b rd=%b",
            $time,
            dut.u_mesh.R11.buffered_valid,

            dut.u_mesh.R11.input_data[2],
            dut.u_mesh.R11.input_valid[2],
            dut.u_mesh.R11.INPUT_BUFFERS[2].input_buffer_inst.fifo_wr_en,
            dut.u_mesh.R11.buffered_data[2],
            dut.u_mesh.R11.INPUT_BUFFERS[2].input_buffer_inst.fifo_empty,
            dut.u_mesh.R11.INPUT_BUFFERS[2].input_buffer_inst.fifo_rd_en,

            dut.u_mesh.R11.input_data[4],
            dut.u_mesh.R11.input_valid[4],
            dut.u_mesh.R11.INPUT_BUFFERS[4].input_buffer_inst.fifo_wr_en,
            dut.u_mesh.R11.buffered_data[4],
            dut.u_mesh.R11.INPUT_BUFFERS[4].input_buffer_inst.fifo_empty,
            dut.u_mesh.R11.INPUT_BUFFERS[4].input_buffer_inst.fifo_rd_en
        );
    end
end

always @(negedge clk) begin
    if (rst_n &&
        (dut.u_mesh.link_10_to_11_valid ||
         dut.u_mesh.link_01_to_11_valid)) begin

        $display(
            "[UPSTREAM] t=%0t | R10: link_data=%h valid=%b grant_N=%b out_N=%h out_valid_N=%b buffers_valid=%b local_head=%h | R01: link_data=%h valid=%b grant_E=%b out_E=%h out_valid_E=%b buffers_valid=%b local_head=%h",
            $time,

            dut.u_mesh.link_10_to_11_data,
            dut.u_mesh.link_10_to_11_valid,
            dut.u_mesh.R10.grant_by_output[1],
            dut.u_mesh.R10.output_data[1],
            dut.u_mesh.R10.output_valid[1],
            dut.u_mesh.R10.buffered_valid,
            dut.u_mesh.R10.buffered_data[0],

            dut.u_mesh.link_01_to_11_data,
            dut.u_mesh.link_01_to_11_valid,
            dut.u_mesh.R01.grant_by_output[3],
            dut.u_mesh.R01.output_data[3],
            dut.u_mesh.R01.output_valid[3],
            dut.u_mesh.R01.buffered_valid,
            dut.u_mesh.R01.buffered_data[0]
        );
    end
end


    // Temporary diagnostic: compare router internal outputs,
    // output ports, and mesh link nets.
    always @(negedge clk) begin
        if (rst_n && $time >= 100000 && $time <= 160000) begin
            $display(
                "[PORTCHECK] t=%0t | R10 internal=%h port=%h link=%h | R01 internal=%h port=%h link=%h",
                $time,
                dut.u_mesh.R10.output_data[1],
                dut.u_mesh.R10.north_data_out,
                dut.u_mesh.link_10_to_11_data,
                dut.u_mesh.R01.output_data[3],
                dut.u_mesh.R01.east_data_out,
                dut.u_mesh.link_01_to_11_data
            );
        end
    end
endmodule
