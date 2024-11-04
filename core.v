// opcodes, using only the five bits that disambiguate them
// (the low two bits are always 11)
localparam OPCODE_LUI = 5'b01101;
localparam OPCODE_AUIPC = 5'b00101;
localparam OPCODE_JAL = 5'b11011;
localparam OPCODE_JALR = 5'b11001;
localparam OPCODE_BRANCH = 5'b11000;
localparam OPCODE_LOAD = 5'b00000;
localparam OPCODE_STORE = 5'b01000;
localparam OPCODE_IMMEDIATE = 5'b00100;
localparam OPCODE_ARITHMETIC = 5'b01100;
localparam OPCODE_FENCE = 5'b00011; // includes PAUSE instruction
localparam OPCODE_SYSTEM = 5'b11100;

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
localparam FUNCT3_SW = 3'b010;

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

localparam FUNCT3_PRIV = 3'b000;

localparam FUNCT3_CSRRW = 3'b001;
localparam FUNCT3_CSRRS = 3'b010;
localparam FUNCT3_CSRRC = 3'b011;
localparam FUNCT3_CSRRWI = 3'b101;
localparam FUNCT3_CSRRSI = 3'b110;
localparam FUNCT3_CSRRCI = 3'b111;

localparam FUNC12_ECALL = 12'b0;
localparam FUNC12_EBREAK = 12'b1;

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

localparam EXCEPTION_CODE_ILLEGAL_INSTRUCTION = 31'd2;

module core(clock, next_program_counter, program_memory_value, memory_address, memory_write_value, memory_write_sections, memory_read_value);

    input clock;
    input [31:0] program_memory_value;
    input [31:0] memory_read_value;

    output reg [31:0] next_program_counter, memory_address, memory_write_value;
    // MSB 1 means write high half-word, middle bit 1 means write low
    // half-word high byte, LSB means write low byte
    output reg [2:0] memory_write_sections;

    wire [31:0] instruction, alu_result, memory_read_value, next_instruction_address, base_register_read_value_1, base_register_read_value_2, csr_read_value;
    wire [31:0] i_immediate, s_immediate, b_immediate, u_immediate, j_immediate, csr_immediate;
    wire [11:0] func12, csr;
    wire [4:0] opcode;
    wire [4:0] register_read_address_1, register_read_address_2, rd;
    wire [2:0] funct3;
    wire comparator_result;

    reg [31:0] program_counter, register_write_value_1, register_write_value_2, register_read_value_1, register_read_value_2, alu_operand_1, alu_operand_2, comparator_operand_1, comparator_operand_2, csr_write_value;
    initial program_counter = `INITIAL_PROGRAM_COUNTER;
    reg [11:0] csr_address;
    reg [4:0] register_write_address_1, register_write_address_2, load_register, pending_load_register;
    reg [3:0] alu_opcode;
    reg [2:0] comparator_opcode, load_funct3, pending_load_funct3;
    reg csr_write_enable;

    reg trap;
    reg interrupt;
    reg [30:0] exception_code;
    reg stall = 1;

    `ifdef simulation
        reg finish;
        reg error;
    `endif

    registers registers(clock, register_write_address_1, register_write_value_1, register_write_address_2, register_write_value_2, register_read_address_1, base_register_read_value_1, register_read_address_2, base_register_read_value_2);
    alu alu(alu_opcode, alu_operand_1, alu_operand_2, alu_result);
    comparator comparator(comparator_opcode, comparator_operand_1, comparator_operand_2, comparator_result);
    csr control_status_registers(clock, csr_address, csr_read_value, csr_write_value, csr_write_enable);

    assign instruction = program_memory_value;
    assign opcode = instruction[6:2];

    assign i_immediate = { {21{instruction[31]}}, instruction[30:20] };
    assign s_immediate = { {21{instruction[31]}}, instruction[30:25], instruction[11:7] };
    assign b_immediate = { {20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0 };
    assign u_immediate = { instruction[31:12], 12'b0 };
    assign j_immediate = { {12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0 };
    assign csr_immediate = { 27'b0, instruction[19:15] };

    assign funct3 = instruction[14:12];
    assign func12 = instruction[31:20];

    assign register_read_address_1 = instruction[19:15];
    assign register_read_address_2 = instruction[24:20];
    assign rd = instruction[11:7];
    assign csr = instruction[31:20];

    assign next_instruction_address = program_counter + 4;

    always @* begin
        comparator_opcode = 3'bx;
        comparator_operand_1 = 32'bx;
        comparator_operand_2 = 32'bx;

        alu_opcode = 4'bx;
        alu_operand_1 = 32'bx;
        alu_operand_2 = 32'bx;

        register_write_address_1 = 5'b0;
        register_write_value_1 = 32'bx;
        memory_address = 32'bx;
        memory_write_value = 32'bx;
        memory_write_sections = 0;

        csr_write_enable = 0;
        csr_address = 12'bx;

        // load operations take 2 cycles to complete because the memory is
        // synchronous so the register write has to be delayed until the next cycle
        pending_load_register = 5'b0;
        pending_load_funct3 = 3'bx;

        register_read_value_1 = base_register_read_value_1;
        register_read_value_2 = base_register_read_value_2;

        trap = 1'b0;
        interrupt = 1'bx;
        exception_code = 31'bx;

        next_program_counter = program_counter;

        if (load_register != 0) begin
            register_write_address_2 = load_register;
            case (load_funct3)
                FUNCT3_LW: register_write_value_2 = memory_read_value;
                FUNCT3_LH: register_write_value_2 = { {16{memory_read_value[15]}}, memory_read_value[15:0] };
                FUNCT3_LHU: register_write_value_2 = { 16'b0, memory_read_value[15:0] };
                FUNCT3_LB: register_write_value_2 = { {24{memory_read_value[7]}}, memory_read_value[7:0] };
                FUNCT3_LBU: register_write_value_2 = { 24'b0, memory_read_value[7:0] };
                default: register_write_value_2 = 32'bx;
            endcase
            // these are so that the load is reflected in the instruction
            // following the load even though it hasn't actually written to
            // register yet
            if (load_register == register_read_address_1) begin
                register_read_value_1 = register_write_value_2;
            end
            if (load_register == register_read_address_2) begin
                register_read_value_2 = register_write_value_2;
            end
        end else begin
            register_write_address_2 = 0;
            register_write_value_2 = 32'bx;
        end

        if (!stall) begin
            next_program_counter = next_instruction_address;

            case(opcode)
                OPCODE_LUI: begin
                    alu_opcode = ALU_OPCODE_ADD;
                    alu_operand_1 = 0;
                    alu_operand_2 = u_immediate;

                    register_write_address_1 = rd;
                    register_write_value_1 = alu_result;
                end
                OPCODE_AUIPC: begin
                    alu_opcode = ALU_OPCODE_ADD;
                    alu_operand_1 = program_counter;
                    alu_operand_2 = u_immediate;

                    register_write_address_1 = rd;
                    register_write_value_1 = alu_result;
                end
                OPCODE_JAL: begin
                    alu_opcode = ALU_OPCODE_ADD;
                    alu_operand_1 = program_counter;
                    alu_operand_2 = j_immediate;
                    next_program_counter = alu_result;

                    register_write_address_1 = rd;
                    register_write_value_1 = next_instruction_address;
                end
                OPCODE_JALR: begin
                    alu_opcode = ALU_OPCODE_ADD;
                    alu_operand_1 = register_read_value_1;
                    alu_operand_2 = i_immediate;
                    next_program_counter = { alu_result[31:1], 1'b0 };

                    register_write_address_1 = rd;
                    register_write_value_1 = next_instruction_address;
                end
                OPCODE_BRANCH: begin
                    comparator_opcode = funct3;
                    comparator_operand_1 = register_read_value_1;
                    comparator_operand_2 = register_read_value_2;

                    alu_opcode = ALU_OPCODE_ADD;
                    alu_operand_1 = program_counter;
                    alu_operand_2 = b_immediate;

                    if (comparator_result) begin
                        next_program_counter = alu_result;
                    end
                end
                OPCODE_LOAD: begin
                    alu_opcode = ALU_OPCODE_ADD;
                    alu_operand_1 = register_read_value_1;
                    alu_operand_2 = i_immediate;
                    memory_address = alu_result;

                    pending_load_register = rd;
                    pending_load_funct3 = funct3;
                end
                OPCODE_STORE: begin
                    alu_opcode = ALU_OPCODE_ADD;
                    alu_operand_1 = register_read_value_1;
                    alu_operand_2 = s_immediate;
                    memory_address = alu_result;
                    memory_write_value = register_read_value_2;

                    case (funct3)
                        FUNCT3_SW: memory_write_sections = 3'b111;
                        FUNCT3_SH: memory_write_sections = 3'b011;
                        FUNCT3_SB: memory_write_sections = 3'b001;
                        default: memory_write_sections = 3'bx;
                    endcase
                end
                OPCODE_IMMEDIATE: begin
                    if (funct3 == FUNCT3_SLL || funct3 == FUNCT3_SRL || funct3 == FUNCT3_SRA) begin
                        alu_opcode = { instruction[30], funct3 };
                    end else begin
                        alu_opcode = { 1'b0, funct3 };
                    end
                    alu_operand_1 = register_read_value_1;
                    alu_operand_2 = i_immediate;

                    register_write_address_1 = rd;
                    if (funct3 == FUNCT3_SLT || funct3 == FUNCT3_SLTU) begin
                        comparator_opcode = { 1'b1, funct3[0], 1'b0 };
                        comparator_operand_1 = register_read_value_1;
                        comparator_operand_2 = i_immediate;

                        register_write_value_1 = { 31'b0, comparator_result };
                    end else begin
                        register_write_value_1 = alu_result;
                    end
                end
                OPCODE_ARITHMETIC: begin
                    alu_opcode = { instruction[30], funct3 };
                    alu_operand_1 = register_read_value_1;
                    alu_operand_2 = register_read_value_2;

                    register_write_address_1 = rd;
                    if (funct3 == FUNCT3_SLT || funct3 == FUNCT3_SLTU) begin
                        comparator_opcode = { 1'b1, funct3[0], 1'b0 };
                        comparator_operand_1 = register_read_value_1;
                        comparator_operand_2 = register_read_value_2;

                        register_write_value_1 = { 31'b0, comparator_result };
                    end else begin
                        register_write_value_1 = alu_result;
                    end
                end
                OPCODE_SYSTEM: begin
                    case (funct3)
                        FUNCT3_PRIV: begin
                            case (func12)
                                FUNC12_ECALL: begin
                                    `ifdef simulation
                                        finish = 1;
                                    `endif
                                end
                                FUNC12_EBREAK: begin
                                    `ifdef simulation
                                        error = 1'b1;
                                    `endif
                                end
                                default: begin end
                            endcase
                        end
                        FUNCT3_CSRRW: begin
                            csr_address = csr;
                            register_write_address_1 = rd;
                            register_write_value_1 = csr_read_value;
                            csr_write_enable = 1;
                            csr_write_value = register_read_value_1;
                        end
                        FUNCT3_CSRRS: begin
                            csr_address = csr;
                            register_write_address_1 = rd;
                            register_write_value_1 = csr_read_value;
                            if (register_read_address_1 != 0) begin
                                csr_write_enable = 1;
                                csr_write_value = csr_read_value | register_read_value_1;
                            end
                        end
                        FUNCT3_CSRRC: begin
                            csr_address = csr;
                            register_write_address_1 = rd;
                            register_write_value_1 = csr_read_value;
                            if (register_read_address_1 != 0) begin
                                csr_write_enable = 1;
                                csr_write_value = csr_read_value & (~register_read_value_1);
                            end
                        end
                        FUNCT3_CSRRWI: begin
                            csr_address = csr;
                            register_write_address_1 = rd;
                            register_write_value_1 = csr_read_value;
                            csr_write_enable = 1;
                            csr_write_value = csr_immediate;
                        end
                        FUNCT3_CSRRSI: begin
                            csr_address = csr;
                            register_write_address_1 = rd;
                            register_write_value_1 = csr_read_value;
                            if (csr_immediate != 0) begin
                                csr_write_enable = 1;
                                csr_write_value = csr_read_value | csr_immediate;
                            end
                        end
                        FUNCT3_CSRRCI: begin
                            csr_address = csr;
                            register_write_address_1 = rd;
                            register_write_value_1 = csr_read_value;
                            if (csr_immediate != 0) begin
                                csr_write_enable = 1;
                                csr_write_value = csr_read_value & (~csr_immediate);
                            end
                        end
                        default: begin end
                    endcase
                end
                default: begin
                    trap = 1;
                    interrupt = 0;
                    exception_code = EXCEPTION_CODE_ILLEGAL_INSTRUCTION;
                    next_program_counter = { control_status_registers.base, 2'b0 };
                end
            endcase
        end
    end

    always @(posedge clock) begin
        program_counter <= next_program_counter;
        stall <= 0;
        load_register <= pending_load_register;
        load_funct3 <= pending_load_funct3;
    end

    `ifdef simulation
        always @* begin
            if (finish) begin
                $finish;
            end
        end

        always @* begin
            if (error) begin
                $stop;
            end
        end
    `endif

endmodule
