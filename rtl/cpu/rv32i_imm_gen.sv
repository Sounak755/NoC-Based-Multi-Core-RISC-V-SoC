`timescale 1ns/1ps

module rv32i_imm_gen (
    input  logic [31:0] instruction,
    input  logic [2:0]  immediate_type,
    output logic [31:0] immediate
);

    localparam logic [2:0] IMM_I = 3'd0;
    localparam logic [2:0] IMM_S = 3'd1;
    localparam logic [2:0] IMM_B = 3'd2;
    localparam logic [2:0] IMM_U = 3'd3;
    localparam logic [2:0] IMM_J = 3'd4;

    always_comb begin
        immediate = 32'b0;

        case (immediate_type)

            // I-type: ADDI, loads, JALR.
            IMM_I: begin
                immediate = {{20{instruction[31]}},
                             instruction[31:20]};
            end

            // S-type: stores.
            IMM_S: begin
                immediate = {{20{instruction[31]}},
                             instruction[31:25],
                             instruction[11:7]};
            end

            // B-type: conditional branch offset.
            // Bit 0 is implicitly zero.
            IMM_B: begin
                immediate = {{19{instruction[31]}},
                             instruction[31],
                             instruction[7],
                             instruction[30:25],
                             instruction[11:8],
                             1'b0};
            end

            // U-type: LUI, AUIPC.
            IMM_U: begin
                immediate = {instruction[31:12], 12'b0};
            end

            // J-type: JAL offset.
            // Bit 0 is implicitly zero.
            IMM_J: begin
                immediate = {{11{instruction[31]}},
                             instruction[31],
                             instruction[19:12],
                             instruction[20],
                             instruction[30:21],
                             1'b0};
            end

            default: immediate = 32'b0;

        endcase
    end

endmodule