localparam OPCODE_LUI = 7'b0110111;
localparam OPCODE_AUIPC = 7'b0010111;
localparam OPCODE_JAL = 7'b1101111;
localparam OPCODE_JALR = 7'b1100111;
localparam OPCODE_BRANCH = 7'b1100011;
localparam OPCODE_LOAD = 7'b0000011;
localparam OPCODE_STORE = 7'b0100011;
localparam OPCODE_IMMEDIATE = 7'b0010011;
localparam OPCODE_ARITHMETIC = 7'b0110011;
localparam OPCODE_FENCE = 7'b0001111; // includes PAUSE instruction
localparam OPCODE_SYSTEM = 7'b1110011;

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
localparam FUNC12_MRET = 12'b001100000010;
localparam FUNC12_WFI = 12'b000100000101;

// custom instructions
localparam FUNC12_CLEAR_USB_INTERRUPT = 12'b111011000000;
`ifdef simulation
localparam FUNC12_TEST_PASS = 12'b100011000000;
localparam FUNC12_TEST_FAIL = 12'b110011000000;
`endif

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

localparam MCAUSE_ILLEGAL_INSTRUCTION = 2;
localparam MCAUSE_BREAKPOINT = 3;
localparam MCAUSE_ENVIRONMENT_CALL_FROM_M_MODE = 11;
localparam MCAUSE_MACHINE_TIMER_INTERRUPT = (1 << 31) | 7;
localparam MCAUSE_MACHINE_EXTERNAL_INTERRUPT = (1 << 31) | 11;

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
    wire [6:0] opcode;
    wire [4:0] register_read_address_1, register_read_address_2, rd;
    wire [2:0] funct3;
    wire comparator_result;
    wire csr_is_read_only;

    reg [31:0] program_counter, register_write_value_1, register_write_value_2, register_read_value_1, register_read_value_2, alu_operand_1, alu_operand_2, comparator_operand_1, comparator_operand_2, csr_write_value;
    initial program_counter = `INITIAL_PROGRAM_COUNTER;
    reg [11:0] csr_address;
    reg [4:0] register_write_address_1, register_write_address_2, load_register, pending_load_register;
    reg [3:0] alu_opcode;
    reg [2:0] comparator_opcode, load_funct3, pending_load_funct3;
    reg csr_write_enable;

    reg trap;
    reg [31:0] mcause;
    reg return_from_trap;
    reg stall = 1;
    reg clear_mip_meip;

    `ifdef simulation
        reg finish;
        reg error;
    `endif

    registers registers(clock, register_write_address_1, register_write_value_1, register_write_address_2, register_write_value_2, register_read_address_1, base_register_read_value_1, register_read_address_2, base_register_read_value_2);
    alu alu(alu_opcode, alu_operand_1, alu_operand_2, alu_result);
    comparator comparator(comparator_opcode, comparator_operand_1, comparator_operand_2, comparator_result);
    csr control_status_registers(clock, csr_address, csr_read_value, csr_write_value, csr_write_enable);

    assign instruction = program_memory_value;
    assign opcode = instruction[6:0];

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
    assign csr_is_read_only = csr[11:10] == 2'b11;

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
        mcause = 32'bx;
        return_from_trap = 1'b0;
        clear_mip_meip = 0;

        next_program_counter = program_counter;

        if (load_register != 0) begin
            register_write_address_2 = load_register;
            case (load_funct3)
                FUNCT3_LW: register_write_value_2 = memory_read_value;
                FUNCT3_LH: register_write_value_2 = { {16{memory_read_value[15]}}, memory_read_value[15:0] };
                FUNCT3_LHU: register_write_value_2 = { 16'b0, memory_read_value[15:0] };
                FUNCT3_LB: register_write_value_2 = { {24{memory_read_value[7]}}, memory_read_value[7:0] };
                FUNCT3_LBU: register_write_value_2 = { 24'b0, memory_read_value[7:0] };
                // will not happen due to error checking performed when the
                // instruction was decoded
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

        if (control_status_registers.mstatus_mie && control_status_registers.mie_mtie && control_status_registers.mip_mtip) begin
            raise(MCAUSE_MACHINE_TIMER_INTERRUPT);
        end else if (control_status_registers.mstatus_mie && control_status_registers.mie_meie && control_status_registers.mip_meip) begin
            raise(MCAUSE_MACHINE_EXTERNAL_INTERRUPT);
        end else if (!stall) begin
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
                    if (funct3 == 3'b010 || funct3 == 'b011) begin
                        raise(MCAUSE_ILLEGAL_INSTRUCTION);
                    end else begin
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
                end
                OPCODE_LOAD: begin
                    if (funct3 == 3'b011 || funct3 == 3'b110 || funct3 == 3'b111) begin
                        raise(MCAUSE_ILLEGAL_INSTRUCTION);
                    end else begin
                        alu_opcode = ALU_OPCODE_ADD;
                        alu_operand_1 = register_read_value_1;
                        alu_operand_2 = i_immediate;
                        memory_address = alu_result;

                        pending_load_register = rd;
                        pending_load_funct3 = funct3;
                    end
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
                        // this could be raised earlier to avoid specifying
                        // values that aren't needed but there are fewer
                        // cells in the synthesized netlist by putting it here
                        // and the code is simpler; this may complicate
                        // the netlist with future changes so that should be
                        // checked later
                        default: raise(MCAUSE_ILLEGAL_INSTRUCTION);
                    endcase
                end
                OPCODE_IMMEDIATE: begin
                    // all funct3 values are valid here
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
                    // all funct3 values are valid here
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
                            if (register_read_address_1 == 0 && rd == 0) begin
                                case (func12)
                                    FUNC12_ECALL: begin
                                        raise(MCAUSE_ENVIRONMENT_CALL_FROM_M_MODE);
                                    end
                                    FUNC12_EBREAK: begin
                                        raise(MCAUSE_BREAKPOINT);
                                    end
                                    FUNC12_MRET: begin
                                        return_from_trap = 1;
                                        next_program_counter = { control_status_registers.mepc, 2'b0 };
                                    end
                                    FUNC12_WFI: begin
                                        // nop
                                    end
                                    // custom instruction for telling the usb
                                    // hardware the packet has been handled
                                    FUNC12_CLEAR_USB_INTERRUPT: begin
                                        clear_mip_meip = 1;
                                    end
                                    `ifdef simulation 
                                        // custom instructions for running tests
                                        FUNC12_TEST_PASS: begin
                                            finish = 1; 
                                        end
                                        FUNC12_TEST_FAIL: begin
                                            error = 1;
                                        end
                                    `endif
                                    default: begin
                                        raise(MCAUSE_ILLEGAL_INSTRUCTION);
                                    end
                                endcase
                            end else begin
                                raise(MCAUSE_ILLEGAL_INSTRUCTION);
                            end
                        end
                        FUNCT3_CSRRW: begin
                            if (!csr_is_read_only) begin
                                csr_address = csr;
                                register_write_address_1 = rd;
                                register_write_value_1 = csr_read_value;
                                csr_write_enable = 1;
                                csr_write_value = register_read_value_1;
                            end else begin
                                raise(MCAUSE_ILLEGAL_INSTRUCTION);
                            end
                        end
                        FUNCT3_CSRRS: begin
                            if (!(csr_is_read_only && register_read_address_1 != 0)) begin
                                csr_address = csr;
                                register_write_address_1 = rd;
                                register_write_value_1 = csr_read_value;
                                if (register_read_address_1 != 0) begin
                                    csr_write_enable = 1;
                                    csr_write_value = csr_read_value | register_read_value_1;
                                end
                            end else begin
                                raise(MCAUSE_ILLEGAL_INSTRUCTION);
                            end
                        end
                        FUNCT3_CSRRC: begin
                            if (!(csr_is_read_only && register_read_address_1 != 0)) begin
                                csr_address = csr;
                                register_write_address_1 = rd;
                                register_write_value_1 = csr_read_value;
                                if (register_read_address_1 != 0) begin
                                    csr_write_enable = 1;
                                    csr_write_value = csr_read_value & (~register_read_value_1);
                                end
                            end else begin
                                raise(MCAUSE_ILLEGAL_INSTRUCTION);
                            end
                        end
                        FUNCT3_CSRRWI: begin
                            if (!csr_is_read_only) begin
                                csr_address = csr;
                                register_write_address_1 = rd;
                                register_write_value_1 = csr_read_value;
                                csr_write_enable = 1;
                                csr_write_value = csr_immediate;
                            end else begin
                                raise(MCAUSE_ILLEGAL_INSTRUCTION);
                            end
                        end
                        FUNCT3_CSRRSI: begin
                            if (!(csr_is_read_only && register_read_address_1 != 0)) begin
                                csr_address = csr;
                                register_write_address_1 = rd;
                                register_write_value_1 = csr_read_value;
                                if (csr_immediate != 0) begin
                                    csr_write_enable = 1;
                                    csr_write_value = csr_read_value | csr_immediate;
                                end
                            end else begin
                                raise(MCAUSE_ILLEGAL_INSTRUCTION);
                            end
                        end
                        FUNCT3_CSRRCI: begin
                            if (!(csr_is_read_only && register_read_address_1 != 0)) begin
                                csr_address = csr;
                                register_write_address_1 = rd;
                                register_write_value_1 = csr_read_value;
                                if (csr_immediate != 0) begin
                                    csr_write_enable = 1;
                                    csr_write_value = csr_read_value & (~csr_immediate);
                                end
                            end else begin
                                raise(MCAUSE_ILLEGAL_INSTRUCTION);
                            end
                        end
                        default: begin 
                            raise(MCAUSE_ILLEGAL_INSTRUCTION);
                        end
                    endcase
                end
                default: begin
                    raise(MCAUSE_ILLEGAL_INSTRUCTION);
                end
            endcase
        end
    end

    always @(posedge clock) begin
        program_counter <= next_program_counter;
        stall <= 0;
        load_register <= pending_load_register;
        load_funct3 <= pending_load_funct3;
        if (clear_mip_meip) begin
            control_status_registers.mip_meip <= 0;
        end
    end

    task raise(input [31:0] _mcause);
        trap = 1;
        mcause = _mcause;
        next_program_counter = { control_status_registers.base, 2'b0 };
    endtask

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
