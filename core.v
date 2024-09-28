// opcodes, using only the five bits that disambiguate them
// (the low two bits are always 11)
localparam LUI_OPCODE = 5'b01101;
localparam AUIPC_OPCODE = 5'b00101;
localparam JAL_OPCODE = 5'b11011;
localparam JALR_OPCODE = 5'b11001;
localparam BRANCH_OPCODE = 5'b11000;
localparam LOAD_OPCODE = 5'b00000;
localparam STORE_OPCODE = 5'b01000;
localparam IMMEDIATE_OPCODE = 5'b00100;
localparam ARITHMETIC_OPCODE = 5'b01100;
localparam FENCE_OPCODE = 5'b00011; // includes PAUSE instruction
localparam SYSTEM_OPCODE = 5'b11100;

localparam FUNCT3_JALR = 3'b000;

localparam FUNCT3_BEQ = 3'b000;
localparam FUNCT3_BNE = 3'b001;
localparam FUNCT3_BLT = 3'b100;
localparam FUNCT3_BGE = 3'b101;
localparam FUNCT3_BLTU = 3'b110;
localparam FUNCT3_BGEU = 3'b111;

localparam FUNCT3_LB = 3'b000;
localparam FUNCT3_LH = 3'b001;
localparam FUNCT3_LW = 3'b010;
localparam FUNCT3_LBU = 3'b100;
localparam FUNCT3_LHU = 3'b101;

localparam FUNCT3_SB = 3'b000;
localparam FUNCT3_SH = 3'b001;

// funct3 values for arithmetic and immediate instructions are the same,
// so use the same for both
localparam FUNCT3_ADD = 3'b000;
localparam FUNCT3_SUB = 3'b000;
localparam FUNCT3_SLL = 3'b001;
localparam FUNCT3_SLT = 3'b010;
localparam FUNCT3_SLTU = 3'b011;
localparam FUNCT3_XOR = 3'b100;
localparam FUNCT3_SRL = 3'b101;
localparam FUNCT3_SRA = 3'b101;
localparam FUNCT3_OR = 3'b110;
localparam FUNCT3_AND = 3'b111;

localparam FUNCT3_FENCE = 3'b000;
localparam FUNCT3_SYSTEM = 3'b000;

// the bit at index 3 is the bit at index 30 in the corresponding instruction
// logic to produce the alu opcode relies on these being defined this way
localparam ALU_OPCODE_ADD = { 1'b0, FUNCT3_ADD };
localparam ALU_OPCODE_SUBTRACT = { 1'b1, FUNCT3_SUB };
localparam ALU_OPCODE_LEFT_SHIFT = { 1'b0, FUNCT3_SLL };
localparam ALU_OPCODE_XOR = { 1'b0, FUNCT3_XOR };
localparam ALU_OPCODE_RIGHT_SHIFT_LOGICAL = { 1'b0, FUNCT3_SRL };
localparam ALU_OPCODE_RIGHT_SHIFT_ARITHMETIC = { 1'b1, FUNCT3_SRA };
localparam ALU_OPCODE_OR = { 1'b0, FUNCT3_OR };
localparam ALU_OPCODE_AND = { 1'b0, FUNCT3_AND };

module core(clk, program_counter, program_memory_value, memory_address, memory_value, memory_write_sections);

    input clk;
    input [31:0] program_memory_value;

    output reg [31:0] program_counter; 
    // MSB 1 means write high half-word, middle bit 1 means write low
    // half-word high byte, LSB means write low byte
    // all zeros means read
    output reg [2:0] memory_write_sections;
    output [31:0] memory_address;

    inout [31:0] memory_value;

    wire [31:0] instruction, alu_result, memory_read_value, next_instruction_address, register_read_value_1, register_read_value_2;
    wire [19:0] u_immediate, j_immediate;
    wire [11:0] i_immediate, s_immediate, b_immediate;
    wire [4:0] opcode;
    wire [4:0] register_read_address_1, register_read_address_2, register_write_address;
    wire [2:0] funct3;
    wire comparator_result;

    reg [31:0] next_program_counter, register_write_value, alu_operand_1, alu_operand_2, comparator_operand_1, comparator_operand_2;
    reg [3:0] alu_opcode;
    reg [2:0] comparator_opcode;

    registers registers(clk, register_write_address, register_write_value, register_read_address_1, register_read_value_1, register_read_address_2, register_read_value_2);
    alu alu(alu_opcode, alu_operand_1, alu_operand_2, alu_result);
    comparator comparator(comparator_opcode, comparator_operand_1, comparator_operand_2, comparator_result);

    assign instruction = program_memory_value;
    assign opcode = instruction[6:2];

    assign i_immediate = instruction[31:20];
    assign s_immediate = { instruction[31:25], instruction[11:7] };
    assign b_immediate = { instruction[31], instruction[7], instruction[30:25], instruction[11:8] };
    assign u_immediate = instruction[31:12];
    assign j_immediate = { instruction[31], instruction[19:12], instruction[20], instruction[30:21] };

    assign funct3 = instruction[14:12];

    assign register_read_address_1 = instruction[19:15];
    assign register_read_address_2 = instruction[24:20];
    assign register_write_address = (opcode != BRANCH_OPCODE && opcode != STORE_OPCODE && opcode != FENCE_OPCODE) ? instruction[11:7] : 0;

    assign memory_value = (opcode == STORE_OPCODE) ? register_read_value_2 : 0;
    assign memory_address = alu_result;

    assign next_instruction_address = program_counter + 4;

    always @* begin
        comparator_opcode = 3'bx;
        comparator_operand_1 = 32'bx;
        comparator_operand_2 = 32'bx;

        alu_opcode = 4'bx;
        alu_operand_1 = 32'bx;
        alu_operand_2 = 32'bx;

        register_write_value = 32'bx;
        memory_write_sections = 0;

        next_program_counter = next_instruction_address;

        case(opcode)
            LUI_OPCODE: begin
                alu_operand_1 = 0;
                alu_operand_2 = { u_immediate, 12'b0 };
            end
            AUIPC_OPCODE: begin
                alu_operand_1 = program_counter;
                alu_operand_2 = { u_immediate, 12'b0 };
            end
            JAL_OPCODE: begin
                alu_operand_1 = program_counter;
                alu_operand_2 = { {11{j_immediate[19]}}, j_immediate, 1'b0 };
                next_program_counter = alu_result;

                register_write_value = next_instruction_address;
            end
            JALR_OPCODE: begin
                alu_operand_1 = register_read_value_1;
                alu_operand_2 = { {20{i_immediate[11]}}, i_immediate };
                next_program_counter = { alu_result[31:1], 1'b0 };

                register_write_value = next_instruction_address;
            end
            BRANCH_OPCODE: begin
                comparator_opcode = funct3;
                comparator_operand_1 = register_read_value_1;
                comparator_operand_2 = register_read_value_2;

                alu_operand_1 = program_counter;
                alu_operand_2 = { {19{b_immediate[11]}}, b_immediate, 1'b0 };

                if (comparator_result) begin
                    next_program_counter = alu_result;
                end
            end
            LOAD_OPCODE: begin
                alu_operand_1 = register_read_value_1;
                alu_operand_2 = { {20{i_immediate[11]}}, i_immediate };

                case (funct3)
                    FUNCT3_LB: register_write_value = { {24{memory_value[7]}}, memory_value[7:0] };
                    FUNCT3_LH: register_write_value = { {16{memory_value[15]}}, memory_value[15:0] };
                    FUNCT3_LBU: register_write_value = { 24'b0, memory_value[7:0] };
                    FUNCT3_LHU: register_write_value = { 16'b0, memory_value[15:0] };
                    default: register_write_value = memory_value; // LW
                endcase
            end
            STORE_OPCODE: begin
                alu_operand_1 = program_counter;
                alu_operand_2 = { {20{s_immediate[11]}}, s_immediate };

                case (funct3)
                    FUNCT3_SB: memory_write_sections = 3'b001;
                    FUNCT3_SH: memory_write_sections = 3'b011;
                    default: memory_write_sections = 3'b111; // SW 
                endcase
            end
            IMMEDIATE_OPCODE: begin
                if (funct3 == FUNCT3_SLL || funct3 == FUNCT3_SRL || funct3 == FUNCT3_SRA) begin
                    alu_opcode = { instruction[30], funct3 };
                end else begin
                    alu_opcode = { 1'b0, funct3 };
                end
                alu_operand_1 = register_read_value_1;
                alu_operand_2 = { {20{i_immediate[11]}}, i_immediate };

                if (funct3 == FUNCT3_SLT || funct3 == FUNCT3_SLTU) begin
                    comparator_opcode = { 1'b1, funct3[0], 1'b0 };
                    comparator_operand_1 = register_read_value_1;
                    comparator_operand_2 = { 20'b0, i_immediate };

                    register_write_value = { 31'b0, comparator_result };
                end else begin
                    register_write_value = alu_result;
                end
            end
            ARITHMETIC_OPCODE: begin
                alu_opcode = { instruction[30], funct3 };
                alu_operand_1 = register_read_value_1;
                alu_operand_2 = register_read_value_2;

                if (funct3 == FUNCT3_SLT || funct3 == FUNCT3_SLTU) begin
                    comparator_opcode = { 1'b1, funct3[0], 1'b0 };
                    comparator_operand_1 = register_read_value_1;
                    comparator_operand_2 = register_read_value_2;

                    register_write_value = { 31'b0, comparator_result };
                end else begin
                    register_write_value = alu_result;
                end
            end
            // to avoid a synthesizer warning for incomplete case
            default: begin end
        endcase
    end

    always @(posedge clk) begin
        program_counter = next_program_counter;
    end

    /*
    initial begin
        while (1) begin
            // #2 $display("alu1: %0h, alu2: %0h", alu_operand_1, alu_operand_2);
            // $display("alu_result: %0d", alu_result);
            // #2 $display("opcode: %0h", opcode);
            // $display("i_immediate: %0h", i_immediate);
            #2;
            // #2 $display("instruction: %0h bit 31: ", instruction, instruction[31]);
        end
    end
    */
endmodule
