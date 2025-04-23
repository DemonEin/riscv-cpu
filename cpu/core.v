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

`ifdef simulation
localparam FUNC12_TEST_PASS = 12'b100011000000;
localparam FUNC12_TEST_FAIL = 12'b110011000000;
localparam FUNC12_SIMULATION_PRINT = 12'b000011000000;
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

localparam ADDRESS_MVENDORID = 12'hF11;
localparam ADDRESS_MARCHID = 12'hF12;
localparam ADDRESS_MIMPID = 12'hF13;
localparam ADDRESS_MHARTID = 12'hF14;
localparam ADDRESS_MCONFIGPTR = 12'hF15;

localparam ADDRESS_MSTATUS = 12'h300;
localparam ADDRESS_MISA = 12'h301;
localparam ADDRESS_MIE = 12'h304;
localparam ADDRESS_MTVEC = 12'h305;
localparam ADDRESS_MCOUNTEREN = 12'h306;
localparam ADDRESS_MSTATUSH = 12'h310;

localparam ADDRESS_MSCRATCH = 12'h340;
localparam ADDRESS_MEPC = 12'h341;
localparam ADDRESS_MCAUSE = 12'h342;
localparam ADDRESS_MTVAL = 12'h343;
localparam ADDRESS_MIP = 12'h344;
localparam ADDRESS_MTINST = 12'h34A;
localparam ADDRESS_MTVAL2 = 12'h34B;

localparam ADDRESS_MENVCFG = 12'h30A;
localparam ADDRESS_MENVCFGH = 12'h31A;

localparam ADDRESS_MHPMCOUNTER3 = 12'hB03;
localparam ADDRESS_MHPMCOUNTER31 = 12'hB1F;
localparam ADDRESS_MHPMCOUNTER3H = 12'hB83;
localparam ADDRESS_MHPMCOUNTER31H = 12'hB9F;

localparam ADDRESS_MHPMEVENT3 = 12'h323;
localparam ADDRESS_MHPMEVENT31 = 12'h33F;
localparam ADDRESS_MHPMEVENT3H = 12'h723;
localparam ADDRESS_MHPMEVENT31H = 12'h73F;

localparam ADDRESS_MCYCLE = 12'hB00;
localparam ADDRESS_MINSTRET = 12'hB02;

localparam ADDRESS_MCYCLEH = 12'hB80;
localparam ADDRESS_MINSTRETH = 12'hB82;

module core(
    input clock,
    output reg [31:0] next_program_counter,
    input [31:0] program_memory_value,
    output reg [31:0] memory_address,
    output reg [31:0] memory_write_value,
    output reg [2:0] memory_write_sections, // which bytes to write within the memory word
    input [31:0] memory_read_value,
    input usb_packet_ready,
    output reg handled_usb_packet,
    input mip_mtip // machine timer interrupt pending 
);
    wire [31:0] alu_result, base_register_read_value_1, base_register_read_value_2;
    wire comparator_result;

    registers registers(clock, register_write_address_1, register_write_value_1, register_write_address_2, register_write_value_2, register_read_address_1, base_register_read_value_1, register_read_address_2, base_register_read_value_2);
    alu alu(alu_opcode, alu_operand_1, alu_operand_2, alu_result);
    comparator comparator(comparator_opcode, comparator_operand_1, comparator_operand_2, comparator_result);

    wire [31:0] instruction = program_memory_value;
    wire [6:0] opcode = instruction[6:0];
    wire [31:0] next_instruction_address = program_counter + 4;

    wire [31:0] i_immediate = { {21{instruction[31]}}, instruction[30:20] };
    wire [31:0] s_immediate = { {21{instruction[31]}}, instruction[30:25], instruction[11:7] };
    wire [31:0] b_immediate = { {20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0 };
    wire [31:0] u_immediate = { instruction[31:12], 12'b0 };
    wire [31:0] j_immediate = { {12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0 };
    wire [31:0] csr_immediate = { 27'b0, instruction[19:15] };

    wire [2:0] funct3 = instruction[14:12];
    wire [11:0] func12 = instruction[31:20];

    wire [4:0] register_read_address_1 = instruction[19:15];
    wire [4:0] register_read_address_2 = instruction[24:20];
    wire [4:0] rd = instruction[11:7];

    wire [11:0] csr = instruction[31:20];
    wire csr_is_read_only = csr[11:10] == 2'b11;

    wire mip_meip = usb_packet_ready; // machine external interrupt pending
    wire [63:0] menvcfg = {
        1'b0 /* STCE */,
        1'b0 /* PBMTE */,
        1'b0 /* ADUE */,
        1'b0 /* CDE */,
        26'b0 /* WPRI */,
        2'b0 /* PMM */,
        24'b0 /* WPRI */,
        1'b0 /* CBZE */,
        1'b0 /* CBCFE */,
        2'b0 /* CBIE */,
        3'b0 /* WPRI */,
        1'b0 /* FIOM */
    };

    wire [63:0] next_mcycle = mcycle + 1;
    wire [63:0] next_minstret = stall || trap ? minstret : minstret + 1;;

    // wire-like regs set in the following combinational block
    reg [31:0] register_write_value_1,
        register_write_value_2,
        register_read_value_1,
        register_read_value_2,
        alu_operand_1,
        alu_operand_2,
        comparator_operand_1,
        comparator_operand_2,
        csr_write_value;
    reg [11:0] csr_address;
    reg [4:0] register_write_address_1,
        register_write_address_2,
        pending_load_register;
    reg [3:0] alu_opcode;
    reg [2:0] comparator_opcode,
        pending_load_funct3;
    reg csr_write_enable;

    reg trap;
    reg [31:0] trap_mcause;
    reg return_from_trap;

    `ifdef simulation
        reg finish;
        reg fail;
        reg simulation_print;
        reg illegal_instruction;
    `endif

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
        csr_write_value = 32'bx;
        csr_address = 12'bx;

        // load operations take 2 cycles to complete because the memory is
        // synchronous so the register write has to be delayed until the next cycle
        pending_load_register = 5'b0;
        pending_load_funct3 = 3'bx;

        register_read_value_1 = base_register_read_value_1;
        register_read_value_2 = base_register_read_value_2;

        trap = 1'b0;
        trap_mcause = 32'bx;
        return_from_trap = 1'b0;
        handled_usb_packet = 0;

        next_program_counter = program_counter;

        `ifdef simulation
            simulation_print = 0;
        `endif

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

        if (mstatus_mie && mie_mtie && mip_mtip) begin
            raise(MCAUSE_MACHINE_TIMER_INTERRUPT);
        end else if (mstatus_mie && mie_meie && mip_meip) begin
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
                        raise_illegal_instruction();
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
                        raise_illegal_instruction();
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
                        default: raise_illegal_instruction();
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
                                        next_program_counter = { mepc, 2'b0 };
                                    end
                                    FUNC12_WFI: begin
                                        // nop
                                    end
                                    `ifdef simulation 
                                        // custom instructions for running tests
                                        FUNC12_TEST_PASS: begin
                                            finish = 1; 
                                        end
                                        FUNC12_TEST_FAIL: begin
                                            fail = 1;
                                        end
                                        FUNC12_SIMULATION_PRINT: begin
                                            simulation_print = 1;
                                        end
                                    `endif
                                    default: begin
                                        raise_illegal_instruction();
                                    end
                                endcase
                            end else begin
                                raise_illegal_instruction();
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
                                raise_illegal_instruction();
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
                                raise_illegal_instruction();
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
                                raise_illegal_instruction();
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
                                raise_illegal_instruction();
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
                                raise_illegal_instruction();
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
                                raise_illegal_instruction();
                            end
                        end
                        default: begin 
                            raise_illegal_instruction();
                        end
                    endcase
                end
                default: begin
                    raise_illegal_instruction();
                end
            endcase
        end
    end

    // register-like regs written in the following block
    reg [31:0] program_counter = `INITIAL_PROGRAM_COUNTER;
    reg [4:0] load_register;
    reg [2:0] load_funct3;
    reg stall = 1;

    reg mstatus_mie = 0; // machine interrupt enable
    reg mstatus_mpie; // machine prior interrupt enable
    reg [29:0] base;
    reg mip_msip; // machine software interrupt pending

    // machine interrupt enable
    reg mie_meie; // machine external interrupt enable
    reg mie_mtie; // machine timer interrupt enable
    reg mie_msie; // machine software interrupt enable

    reg [63:0] mcycle = 0;
    reg [63:0] minstret = 0;
    reg [31:0] mscratch;
    reg [29:0] mepc; // machine exception program counter
    reg [31:0] mcause = 0;

    always @(posedge clock) begin
        program_counter <= next_program_counter;
        stall <= 0;
        load_register <= pending_load_register;
        load_funct3 <= pending_load_funct3;

        if (trap) begin
            mcause <= trap_mcause;
            mepc <= program_counter[31:2];
            mstatus_mpie <= mstatus_mie;
            mstatus_mie <= 0;
        end else if (return_from_trap) begin
            mstatus_mie <= mstatus_mpie;
            mstatus_mpie <= 1;
        end else if (csr_write_enable) begin
            case (csr_address)
                ADDRESS_MSTATUS: begin
                    mstatus_mie <= csr_write_value[3];
                    mstatus_mpie <= csr_write_value[7];
                end
                ADDRESS_MTVEC: begin
                    base <= csr_write_value[31:2];
                end
                ADDRESS_MIP: begin
                    // all are read-only
                end
                ADDRESS_MIE: begin
                    // this could be read-only, TODO consider
                    mie_msie <= csr_write_value[3];
                    mie_mtie <= csr_write_value[7];
                    mie_meie <= csr_write_value[11];
                end
                ADDRESS_MSCRATCH: begin
                    mscratch <= csr_write_value;
                end
                ADDRESS_MEPC: begin
                    mepc <= csr_write_value[31:2];
                end
                ADDRESS_MCAUSE: begin
                    mcause <= csr_write_value;
                end
                default: begin
                end
            endcase
        end

        if (csr_write_enable) begin
            case (csr_address)
                ADDRESS_MCYCLE: mcycle[31:0] <= csr_write_value;
                ADDRESS_MCYCLEH: mcycle[63:32] <= csr_write_value;
                default: mcycle <= next_mcycle;
            endcase

            case (csr_address)
                ADDRESS_MINSTRET: minstret[31:0] <= csr_write_value;
                ADDRESS_MINSTRETH: minstret[63:32] <= csr_write_value;
                default: minstret <= next_minstret;
            endcase
        end else begin
            mcycle <= next_mcycle;
            minstret <= next_minstret;
        end
    end

    task raise_illegal_instruction();
        raise(MCAUSE_ILLEGAL_INSTRUCTION);
        `ifdef simulation
            illegal_instruction = 1;
        `endif
    endtask

    task raise(input [31:0] _mcause);
        trap = 1;
        trap_mcause = _mcause;
        next_program_counter = { base, 2'b0 };
    endtask

    // wire-like regs set in the following combinational block
    reg [31:0] csr_read_value;

    always @* begin
        case (csr_address)
            ADDRESS_MISA: begin
                csr_read_value = {
                    2'b01 /* MXL */,
                    4'b0,
                    26'b1 << 8 /* Extensions */
                };
            end
            ADDRESS_MVENDORID: begin
                csr_read_value = 0;
            end
            ADDRESS_MARCHID: begin
                csr_read_value = 0;
            end
            ADDRESS_MIMPID: begin
                csr_read_value = 0;
            end
            ADDRESS_MHARTID: begin
                csr_read_value = 0;
            end
            ADDRESS_MSTATUS: begin
                csr_read_value = {
                    1'b0 /* SD */,
                    8'b0 /* WPRI */,
                    1'b0 /* TSR */,
                    1'b0 /* TW */,
                    1'b0 /* TVM */,
                    1'b0 /* MXR */,
                    1'b0 /* SUM */,
                    1'b0 /* MPRV */,
                    2'b0 /* XS */,
                    2'b0 /* FS */,
                    2'b11 /* MPP */,
                    2'b0 /* VS */,
                    1'b0 /* SPP */,
                    mstatus_mpie,
                    1'b0 /* UBE */,
                    1'b0 /* SPIE */,
                    1'b0 /* WPRI */,
                    mstatus_mie,
                    1'b0 /* WPRI */,
                    1'b0 /* SIE */,
                    1'b0 /* WPRI */
                };
            end
            ADDRESS_MSTATUSH: begin
                csr_read_value = {
                    26'b0 /* WPRI */,
                    1'b0 /* MBE */,
                    1'b0 /* SBE */,
                    4'b0 /* WPRI */
                };
            end
            ADDRESS_MTVEC: begin
                csr_read_value = {
                    base,
                    2'b0 /* MODE */
                };
            end
            ADDRESS_MIP: begin
                csr_read_value = {
                    16'b0 /* platform defined */,
                    2'b0,
                    1'b0 /* LCOFIP */,
                    1'b0,
                    mip_meip,
                    1'b0,
                    1'b0 /* SEIP */,
                    1'b0,
                    mip_mtip,
                    1'b0,
                    1'b0 /* STIP */,
                    1'b0,
                    mip_msip,
                    1'b0,
                    1'b0 /* SSIP */,
                    1'b0
                };
            end
            ADDRESS_MIE: begin
                csr_read_value = {
                    16'b0 /* platform defined */,
                    2'b0,
                    1'b0 /* LCOFIE */,
                    1'b0,
                    mie_meie,
                    1'b0,
                    1'b0 /* SEIP */,
                    1'b0,
                    mie_mtie,
                    1'b0,
                    1'b0 /* STIP */,
                    1'b0,
                    mie_msie,
                    1'b0,
                    1'b0 /* SSIP */,
                    1'b0
                };
            end
            ADDRESS_MCYCLE: begin
                csr_read_value = mcycle[31:0];
            end
            ADDRESS_MCYCLEH: begin
                csr_read_value = mcycle[63:32];
            end
            ADDRESS_MINSTRET: begin
                csr_read_value = minstret[31:0];
            end
            ADDRESS_MINSTRETH: begin
                csr_read_value = minstret[63:32];
            end
            ADDRESS_MSCRATCH: begin
                csr_read_value = mscratch;
            end
            ADDRESS_MEPC: begin
                csr_read_value = { mepc, 2'b0 };
            end
            ADDRESS_MCAUSE: begin
                csr_read_value = mcause;
            end
            ADDRESS_MTVAL: begin
                csr_read_value = 0;
            end
            ADDRESS_MCONFIGPTR: begin
                csr_read_value = 0;
            end
            ADDRESS_MENVCFG: begin
                csr_read_value = menvcfg[31:0];
            end
            ADDRESS_MENVCFGH: begin
                csr_read_value = menvcfg[63:32];
            end
            default: begin
                if ((csr_address >= ADDRESS_MHPMCOUNTER3 && csr_address <= ADDRESS_MHPMCOUNTER31)
                    || (csr_address >= ADDRESS_MHPMCOUNTER3H && csr_address <= ADDRESS_MHPMCOUNTER31H)
                    || (csr_address >= ADDRESS_MHPMEVENT3 && csr_address <= ADDRESS_MHPMEVENT31)
                    || (csr_address >= ADDRESS_MHPMEVENT3H && csr_address <= ADDRESS_MHPMEVENT31H)) begin
                    csr_read_value = 0;
                end else begin
                    csr_read_value = 32'bx;
                end
            end
        endcase
    end

    `ifdef simulation
        reg [31:0] core_file;

        always @* begin
            if (finish) begin
                $finish;
            end
        end

        always @* begin
            if (fail) begin
                $display("got fail instruction");
            end

            if (illegal_instruction) begin
                $display("got illegal instruction");
            end

            if (fail || illegal_instruction) begin
                $display("pc: 0x%h", program_counter);
                $display("registers (decimal/hex):");
                $display("    ra: %d/0x%h", registers.r[1], registers.r[1]);
                $display("    sp: %d/0x%h", registers.r[2], registers.r[2]);
                $display("    gp: %d/0x%h", registers.r[3], registers.r[3]);
                $display("    tp: %d/0x%h", registers.r[4], registers.r[4]);
                $display("    t0: %d/0x%h", registers.r[5], registers.r[5]);
                $display("    t1: %d/0x%h", registers.r[6], registers.r[6]);
                $display("    t2: %d/0x%h", registers.r[7], registers.r[7]);
                $display("    s0: %d/0x%h", registers.r[8], registers.r[8]);
                $display("    s1: %d/0x%h", registers.r[9], registers.r[9]);
                $display("    a0: %d/0x%h", registers.r[10], registers.r[10]);
                $display("    a1: %d/0x%h", registers.r[11], registers.r[11]);
                $display("    a2: %d/0x%h", registers.r[12], registers.r[12]);
                $display("    a3: %d/0x%h", registers.r[13], registers.r[13]);
                $display("    a4: %d/0x%h", registers.r[14], registers.r[14]);
                $display("    a5: %d/0x%h", registers.r[15], registers.r[15]);
                $display("    a6: %d/0x%h", registers.r[16], registers.r[16]);
                $display("    a7: %d/0x%h", registers.r[17], registers.r[17]);
                $display("    s2: %d/0x%h", registers.r[18], registers.r[18]);
                $display("    s3: %d/0x%h", registers.r[19], registers.r[19]);
                $display("    s4: %d/0x%h", registers.r[20], registers.r[20]);
                $display("    s5: %d/0x%h", registers.r[21], registers.r[21]);
                $display("    s6: %d/0x%h", registers.r[22], registers.r[22]);
                $display("    s7: %d/0x%h", registers.r[23], registers.r[23]);
                $display("    s8: %d/0x%h", registers.r[24], registers.r[24]);
                $display("    s9: %d/0x%h", registers.r[25], registers.r[25]);
                $display("    s10: %d/0x%h", registers.r[26], registers.r[26]);
                $display("    s11: %d/0x%h", registers.r[27], registers.r[27]);
                $display("    t3: %d/0x%h", registers.r[28], registers.r[28]);
                $display("    t4: %d/0x%h", registers.r[29], registers.r[29]);
                $display("    t5: %d/0x%h", registers.r[30], registers.r[30]);
                $display("    t6: %d/0x%h", registers.r[31], registers.r[31]);

                core_file = $fopen("core", "w");
                if (core_file != 0) begin
                    for (reg [31:0] i = 0; i < MEMORY_SIZE; i = i + 1) begin
                        $fwriteb(core_file, "%u", top.memory[i]);
                    end
                    $display("core written to ./core");
                    $fclose(core_file);
                end else begin
                    $display("could not create core file");
                end

                $stop;
            end else begin
                core_file = 32'bx;
            end
        end

        always @(posedge clock) begin
            if (simulation_print) begin
                // duplicating code in these two branches but whatever
                if (registers.r[10] >= ADDRESS_USB_DATA_BUFFER && registers.r[10] < ADDRESS_USB_DATA_BUFFER + USB_DATA_BUFFER_SIZE) begin
                    for (reg [31:0] i = registers.r[10]; // start at a0
                            ((top.usb_data_buffer[i / 4] >> ((i % 4) * 8)) & 32'hFF) != 0;
                            i = i + 1) begin
                        // have to duplicate a complex expression but whatever
                        $write("%u", (top.usb_data_buffer[i / 4] >> ((i % 4) * 8)) & 32'hFF);
                    end
                end else begin
                    for (reg [31:0] i = registers.r[10]; // start at a0
                            ((top.memory[i / 4] >> ((i % 4) * 8)) & 32'hFF) != 0;
                            i = i + 1) begin
                        // have to duplicate a complex expression but whatever
                        $write("%u", (top.memory[i / 4] >> ((i % 4) * 8)) & 32'hFF);
                    end
                end
                $fflush(); // doesn't print immediately otherwise
            end
        end
    `endif

endmodule
