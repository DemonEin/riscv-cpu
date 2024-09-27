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

    wire [31:0] instruction, alu_result, memory_read_value, next_program_counter, comparator_operand_1, comparator_operand_2, register_read_value_1, register_read_value_2;
    wire [19:0] u_immediate, j_immediate;
    wire [11:0] i_immediate, s_immediate, b_immediate;
    wire [4:0] opcode;
    wire [4:0] register_read_address_1, register_read_address_2, register_write_address;
    wire [2:0] funct3;
    wire comparator_result;

    reg [31:0] register_write_value, alu_operand_1, alu_operand_2;
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
    assign register_write_address = (opcode != 5'b11000 && opcode != 5'b01000 && opcode != 5'b00011) ? instruction[11:7] : 0;

    assign memory_value = (opcode == 5'b01000) ? register_read_value_2 : 0; // store instructions
    assign memory_address = alu_result;

    assign next_program_counter = program_counter + 4;

    always @* begin
        if (opcode == 5'b11011 || opcode == 5'b11001) begin
             // JAL(R)
            register_write_value = next_program_counter;
        end else if ((opcode == 5'b00100 || opcode == 5'b01100) && (funct3 == 3'b010 || funct3 == 3'b011)) begin
            // SLT(I)(U)
            register_write_value = { 31'b0, comparator_result };
        end else if (opcode == 5'b00000) begin
            // load instructions
            case (funct3)
                3'b000: register_write_value = { {24{memory_value[7]}}, memory_value[7:0] }; // LB
                3'b001: register_write_value = { {16{memory_value[15]}}, memory_value[15:0] }; // LH
                3'b100: register_write_value = { 24'b0, memory_value[7:0] }; // LBU
                3'b101: register_write_value = { 16'b0, memory_value[15:0] }; // LHU
                default: register_write_value = memory_value; // LW
            endcase
        end else begin
            register_write_value = alu_result;
        end
    end

    always @(posedge clk) begin
        case (opcode)
            5'b11011: program_counter = alu_result; // JAL
            5'b11001: program_counter = { alu_result[31:1], 1'b0 }; // JALR
            5'b11000: program_counter = comparator_result ? alu_result : next_program_counter; // branch instructions
            default: program_counter = next_program_counter;
        endcase
    end

    always @* begin
        case (opcode)
            5'b01101: alu_operand_1 = 0; // LUI
            5'b00101: alu_operand_1 = program_counter; // AUIPC
            5'b11011: alu_operand_1 = program_counter; // JAL
            5'b11000: alu_operand_1 = program_counter; // branch instructions
            default: alu_operand_1 = register_read_value_1;
        endcase
    end

    always @* begin
        case (opcode)
            5'b00100: alu_opcode = { instruction[30], funct3 }; // arithmetic immediate instructions
            5'b01100: alu_opcode = { instruction[30], funct3 }; // arithmetic instructions
            default: alu_opcode = 4'b0;
        endcase
    end

    always @* begin
        case (opcode)
            5'b01101: alu_operand_2 = { u_immediate, 12'b0 }; // LUI
            5'b00101: alu_operand_2 = { u_immediate, 12'b0 }; // AUIPC
            5'b11011: alu_operand_2 = { {11{j_immediate[19]}}, j_immediate, 1'b0 }; // JAL
            5'b11001: alu_operand_2 = { {20{i_immediate[11]}}, i_immediate }; // JALR
            5'b11000: alu_operand_2 = { {19{b_immediate[11]}}, b_immediate, 1'b0 }; // branch instructions
            5'b00100: alu_operand_2 = { {20{i_immediate[11]}}, i_immediate }; // arithmetic immediate instructions
            5'b00000: alu_operand_2 = { {20{i_immediate[11]}}, i_immediate }; // load instructions
            5'b01000: alu_operand_2 = { {20{s_immediate[11]}}, s_immediate }; // store instructions
            default: alu_operand_2 = register_read_value_2; // arithmetic instructions
        endcase
    end

    always @* begin
        case (opcode)
            5'b00100: comparator_opcode = { 1'b1, funct3[0], 1'b0 }; // SLTI(U)
            5'b01100: comparator_opcode = { 1'b1, funct3[0], 1'b0 }; // SLT(U)
            default: comparator_opcode = funct3; // branch instructions
        endcase
    end

    assign comparator_operand_1 = register_read_value_1;
    assign comparator_operand_2 = (opcode == 5'b00100) ? { 20'b0, i_immediate } : register_read_value_2;

    always @* begin
        if (opcode == 5'b01000) begin
            case (funct3)
                3'b000: memory_write_sections = 3'b001; // SB
                3'b001: memory_write_sections = 3'b011; // SH
                default: memory_write_sections = 3'b111; // SW 
            endcase
        end else begin
            memory_write_sections = 3'b0;
        end
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
