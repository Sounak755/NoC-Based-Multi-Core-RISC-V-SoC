`timescale 1ns/1ps

module rv32i_decoder (
    input  logic [31:0] instruction,

    output logic        reg_write,
    output logic        alu_src,
    output logic        mem_read,
    output logic        mem_write,
    output logic        mem_to_reg,
    output logic        branch,
    output logic        jump,
    output logic        jalr,
    output logic        illegal_instruction,

    output logic [3:0]  alu_control,
    output logic [2:0]  immediate_type
);

    // ALU control encodings must match rv32i_alu.sv.
    localparam logic [3:0] ALU_ADD  = 4'b0000;
    localparam logic [3:0] ALU_SUB  = 4'b0001;
    localparam logic [3:0] ALU_AND  = 4'b0010;
    localparam logic [3:0] ALU_OR   = 4'b0011;
    localparam logic [3:0] ALU_XOR  = 4'b0100;
    localparam logic [3:0] ALU_SLT  = 4'b0101;
    localparam logic [3:0] ALU_SLTU = 4'b0110;
    localparam logic [3:0] ALU_SLL  = 4'b0111;
    localparam logic [3:0] ALU_SRL  = 4'b1000;
    localparam logic [3:0] ALU_SRA  = 4'b1001;

    // Immediate format encodings.
    localparam logic [2:0] IMM_I = 3'd0;
    localparam logic [2:0] IMM_S = 3'd1;
    localparam logic [2:0] IMM_B = 3'd2;
    localparam logic [2:0] IMM_U = 3'd3;
    localparam logic [2:0] IMM_J = 3'd4;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    always_comb begin
        reg_write          = 1'b0;
        alu_src             = 1'b0;
        mem_read            = 1'b0;
        mem_write           = 1'b0;
        mem_to_reg           = 1'b0;
        branch               = 1'b0;
        jump                 = 1'b0;
        jalr                 = 1'b0;
        illegal_instruction  = 1'b0;
        alu_control          = ALU_ADD;
        immediate_type       = IMM_I;

        case (opcode)

            // R-type register-register operations.
            7'b0110011: begin
                reg_write = 1'b1;

                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_ADD;
                        else if (funct7 == 7'b0100000)
                            alu_control = ALU_SUB;
                        else
                            illegal_instruction = 1'b1;
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SLL;
                        else
                            illegal_instruction = 1'b1;
                    end

                    3'b010: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SLT;
                        else
                            illegal_instruction = 1'b1;
                    end

                    3'b011: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SLTU;
                        else
                            illegal_instruction = 1'b1;
                    end

                    3'b100: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_XOR;
                        else
                            illegal_instruction = 1'b1;
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_control = ALU_SRA;
                        else
                            illegal_instruction = 1'b1;
                    end

                    3'b110: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_OR;
                        else
                            illegal_instruction = 1'b1;
                    end

                    3'b111: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_AND;
                        else
                            illegal_instruction = 1'b1;
                    end

                    default: illegal_instruction = 1'b1;
                endcase
            end

            // I-type arithmetic and logical operations.
            7'b0010011: begin
                reg_write    = 1'b1;
                alu_src      = 1'b1;
                immediate_type = IMM_I;

                case (funct3)
                    3'b000: alu_control = ALU_ADD;
                    3'b010: alu_control = ALU_SLT;
                    3'b011: alu_control = ALU_SLTU;
                    3'b100: alu_control = ALU_XOR;
                    3'b110: alu_control = ALU_OR;
                    3'b111: alu_control = ALU_AND;

                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SLL;
                        else
                            illegal_instruction = 1'b1;
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_control = ALU_SRA;
                        else
                            illegal_instruction = 1'b1;
                    end

                    default: illegal_instruction = 1'b1;
                endcase
            end

            // Loads: LB, LH, LW, LBU, LHU.
            7'b0000011: begin
                reg_write      = 1'b1;
                alu_src        = 1'b1;
                mem_read       = 1'b1;
                mem_to_reg     = 1'b1;
                immediate_type = IMM_I;

                case (funct3)
                    3'b000, 3'b001, 3'b010, 3'b100, 3'b101:
                        alu_control = ALU_ADD;
                    default: illegal_instruction = 1'b1;
                endcase
            end

            // Stores: SB, SH, SW.
            7'b0100011: begin
                alu_src        = 1'b1;
                mem_write      = 1'b1;
                immediate_type = IMM_S;
                alu_control    = ALU_ADD;

                case (funct3)
                    3'b000, 3'b001, 3'b010: ;
                    default: illegal_instruction = 1'b1;
                endcase
            end

            // Conditional branches.
            7'b1100011: begin
                branch         = 1'b1;
                immediate_type = IMM_B;

                case (funct3)
                    3'b000, 3'b001: alu_control = ALU_SUB;  // BEQ, BNE
                    3'b100, 3'b101: alu_control = ALU_SLT;  // BLT, BGE
                    3'b110, 3'b111: alu_control = ALU_SLTU; // BLTU, BGEU
                    default: illegal_instruction = 1'b1;
                endcase
            end

            // JAL.
            7'b1101111: begin
                reg_write      = 1'b1;
                jump           = 1'b1;
                immediate_type = IMM_J;
                alu_control    = ALU_ADD;
            end

            // JALR.
            7'b1100111: begin
                if (funct3 == 3'b000) begin
                    reg_write      = 1'b1;
                    jump           = 1'b1;
                    jalr           = 1'b1;
                    alu_src        = 1'b1;
                    immediate_type = IMM_I;
                    alu_control    = ALU_ADD;
                end
                else begin
                    illegal_instruction = 1'b1;
                end
            end

            // LUI.
            7'b0110111: begin
                reg_write      = 1'b1;
                alu_src        = 1'b1;
                immediate_type = IMM_U;
                alu_control    = ALU_ADD;
            end

            // AUIPC.
            7'b0010111: begin
                reg_write      = 1'b1;
                alu_src        = 1'b1;
                immediate_type = IMM_U;
                alu_control    = ALU_ADD;
            end

            default: illegal_instruction = 1'b1;

        endcase

        // Never allow an unsupported encoding to cause architectural writes.
        if (illegal_instruction) begin
            reg_write = 1'b0;
            mem_read  = 1'b0;
            mem_write = 1'b0;
            mem_to_reg = 1'b0;
            branch    = 1'b0;
            jump      = 1'b0;
        end
    end

endmodule