
module rv32i_data_memory #(
    parameter integer DEPTH_WORDS = 256
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [2:0]  funct3,

    input  logic [31:0] address,
    input  logic [31:0] write_data,
    output logic [31:0] read_data
);

    // Each memory entry stores 32 bits (4 bytes).
    // DEPTH_WORDS = 256 gives 1024 bytes of memory.
    logic [31:0] memory [0:DEPTH_WORDS-1];

    logic [31:0] read_word;
    logic [31:0] shifted_word;

    integer i;

    // ------------------------------------------------------------
    // READ LOGIC
    // Combinational read with byte/halfword/word selection.
    // ------------------------------------------------------------
    always @(*) begin
        read_word    = 32'b0;
        shifted_word = 32'b0;
        read_data    = 32'b0;

        // Prevent out-of-range memory access.
        if (address[31:2] < DEPTH_WORDS) begin
            read_word = memory[address[31:2]];
        end

        // Move the addressed byte/halfword into the least
        // significant bits.
        shifted_word = read_word >> (8 * address[1:0]);

        if (mem_read && (address[31:2] < DEPTH_WORDS)) begin
            case (funct3)

                // LB: Load byte, sign-extended
                3'b000: begin
                    read_data = {
                        {24{shifted_word[7]}},
                        shifted_word[7:0]
                    };
                end

                // LH: Load halfword, sign-extended
                3'b001: begin
                    if (address[0] == 1'b0) begin
                        read_data = {
                            {16{shifted_word[15]}},
                            shifted_word[15:0]
                        };
                    end
                end

                // LW: Load full word (word-aligned only)
                3'b010: begin
                    if (address[1:0] == 2'b00) begin
                        read_data = read_word;
                    end
                end

                // LBU: Load byte, zero-extended
                3'b100: begin
                    read_data = {24'b0, shifted_word[7:0]};
                end

                // LHU: Load halfword, zero-extended
                3'b101: begin
                    if (address[0] == 1'b0) begin
                        read_data = {16'b0, shifted_word[15:0]};
                    end
                end

                // Unsupported load
                default: begin
                    read_data = 32'b0;
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // WRITE LOGIC
    // Synchronous writes on the rising edge of the clock.
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && mem_write &&
            (address[31:2] < DEPTH_WORDS)) begin

            case (funct3)

                // SB: Store the least significant byte
                // in the selected byte lane.
                3'b000: begin
                    case (address[1:0])
                        2'b00: memory[address[31:2]][7:0]
                                    <= write_data[7:0];

                        2'b01: memory[address[31:2]][15:8]
                                    <= write_data[7:0];

                        2'b10: memory[address[31:2]][23:16]
                                    <= write_data[7:0];

                        2'b11: memory[address[31:2]][31:24]
                                    <= write_data[7:0];
                    endcase
                end

                // SH: Store halfword at an aligned address.
                3'b001: begin
                    if (address[0] == 1'b0) begin
                        if (address[1] == 1'b0) begin
                            memory[address[31:2]][15:0]
                                <= write_data[15:0];
                        end
                        else begin
                            memory[address[31:2]][31:16]
                                <= write_data[15:0];
                        end
                    end
                end

                // SW: Store word at a word-aligned address.
                3'b010: begin
                    if (address[1:0] == 2'b00) begin
                        memory[address[31:2]] <= write_data;
                    end
                end

                // Unsupported store: no write.
                default: begin
                    // Intentionally empty.
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // INITIALIZATION
    // Set all words to zero for simulation reproducibility.
    // ------------------------------------------------------------
    initial begin
        for (i = 0; i < DEPTH_WORDS; i = i + 1) begin
            memory[i] = 32'b0;
        end
    end

endmodule
